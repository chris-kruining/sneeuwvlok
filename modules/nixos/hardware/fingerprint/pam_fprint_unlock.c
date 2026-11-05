// Lets a fingerprint login also unlock what the password normally unlocks (kwallet), by keeping the password
// sealed to the tpm with systemd-creds.
//
//   typed   - asks for the password, succeeds when one was typed, so the stack can skip the fingerprint
//   release - decrypts the sealed password into PAM_AUTHTOK, for after the fingerprint matched
//   store   - seals PAM_AUTHTOK, but only when it is the user's actual password and it changed
#define _GNU_SOURCE
#include <crypt.h>
#include <errno.h>
#include <fcntl.h>
#include <shadow.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <syslog.h>
#include <unistd.h>

#include <security/pam_ext.h>
#include <security/pam_modules.h>

#define CRED_NAME "fprint-unlock"
#define MAX_SECRET 4096

static int valid_user(const char *user) {
  size_t len = user ? strlen(user) : 0;
  return len > 0 && len < 64 && user[0] != '.' && strchr(user, '/') == NULL;
}

static int state_path(char *buf, size_t size, const char *user, const char *ext) {
  int n = snprintf(buf, size, "%s/%s.%s", STATE_DIR, user, ext);
  return n > 0 && (size_t)n < size ? 0 : -1;
}

// Runs systemd-creds with `input` on stdin (via a memfd, so a dying child can't SIGPIPE the caller) and
// captures at most `outcap - 1` bytes of stdout.
static int run_creds(char *const argv[], const char *input, char *out, size_t outcap) {
  int infd = -1, outpipe[2] = {-1, -1}, status = 0, rc = -1;
  size_t outlen = 0;

  if (input) {
    size_t len = strlen(input);
    infd = memfd_create("fprint-unlock", MFD_CLOEXEC);
    if (infd < 0 || write(infd, input, len) != (ssize_t)len || lseek(infd, 0, SEEK_SET) != 0) goto out;
  }
  if (pipe2(outpipe, O_CLOEXEC) < 0) goto out;

  pid_t pid = fork();
  if (pid < 0) goto out;
  if (pid == 0) {
    int devnull = open("/dev/null", O_RDWR);
    dup2(infd >= 0 ? infd : devnull, 0);
    dup2(outpipe[1], 1);
    dup2(devnull, 2);
    execv(SYSTEMD_CREDS, argv);
    _exit(127);
  }

  close(outpipe[1]);
  outpipe[1] = -1;
  for (;;) {
    char chunk[512];
    ssize_t r = read(outpipe[0], chunk, sizeof chunk);
    if (r < 0 && errno == EINTR) continue;
    if (r <= 0) break;
    // keep draining past the cap, so the child never blocks on a full pipe
    if (out && outlen + r < outcap) {
      memcpy(out + outlen, chunk, r);
      outlen += r;
    }
    explicit_bzero(chunk, sizeof chunk);
  }
  if (out) out[outlen] = '\0';

  while (waitpid(pid, &status, 0) < 0) {
    if (errno != EINTR) goto out;
  }
  rc = WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : -1;

out:
  if (infd >= 0) close(infd);
  if (outpipe[0] >= 0) close(outpipe[0]);
  if (outpipe[1] >= 0) close(outpipe[1]);
  return rc;
}

static int typed(pam_handle_t *pamh) {
  char *resp = NULL;
  if (pam_prompt(pamh, PAM_PROMPT_ECHO_OFF, &resp, "Password: ") != PAM_SUCCESS || resp == NULL) return PAM_IGNORE;

  int rc = PAM_IGNORE;
  if (resp[0] != '\0' && pam_set_item(pamh, PAM_AUTHTOK, resp) == PAM_SUCCESS) rc = PAM_SUCCESS;

  explicit_bzero(resp, strlen(resp));
  free(resp);
  return rc;
}

static int release(pam_handle_t *pamh, const char *user) {
  char path[512], secret[MAX_SECRET];
  if (state_path(path, sizeof path, user, "cred") < 0 || access(path, R_OK) != 0) return PAM_IGNORE;

  char *const argv[] = {"systemd-creds", "decrypt", "--name=" CRED_NAME, path, "-", NULL};
  int rc = PAM_IGNORE;
  if (run_creds(argv, NULL, secret, sizeof secret) == 0 && secret[0] != '\0') {
    rc = pam_set_item(pamh, PAM_AUTHTOK, secret) == PAM_SUCCESS ? PAM_SUCCESS : PAM_IGNORE;
  } else {
    pam_syslog(pamh, LOG_WARNING, "could not decrypt %s, the password stays needed for the wallet", path);
  }

  explicit_bzero(secret, sizeof secret);
  return rc;
}

static int write_file(const char *path, const char *content) {
  char tmp[600];
  snprintf(tmp, sizeof tmp, "%s.tmp", path);
  int fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
  if (fd < 0) return -1;
  size_t len = strlen(content);
  int ok = write(fd, content, len) == (ssize_t)len && fsync(fd) == 0;
  close(fd);
  return ok && rename(tmp, path) == 0 ? 0 : -1;
}

static int store(pam_handle_t *pamh, const char *user) {
  const void *item = NULL;
  if (pam_get_item(pamh, PAM_AUTHTOK, &item) != PAM_SUCCESS || item == NULL || ((const char *)item)[0] == '\0')
    return PAM_IGNORE;
  const char *authtok = item;

  struct spwd sp, *spp = NULL;
  char spbuf[4096];
  if (getspnam_r(user, &sp, spbuf, sizeof spbuf, &spp) != 0 || spp == NULL) return PAM_IGNORE;

  // This runs after the regular password check, whatever its outcome, so check the password again
  struct crypt_data cd;
  memset(&cd, 0, sizeof cd);
  const char *hashed = crypt_rn(authtok, spp->sp_pwdp, &cd, sizeof cd);
  int matches = hashed != NULL && hashed[0] != '*' && strcmp(hashed, spp->sp_pwdp) == 0;
  explicit_bzero(&cd, sizeof cd);
  if (!matches) return PAM_IGNORE;

  char cred[512], hash[512], current[512] = {0};
  if (state_path(cred, sizeof cred, user, "cred") < 0 || state_path(hash, sizeof hash, user, "hash") < 0)
    return PAM_IGNORE;

  // Sealing goes through the tpm, which is slow, so only do it when the password changed
  FILE *f = fopen(hash, "re");
  if (f) {
    size_t n = fread(current, 1, sizeof current - 1, f);
    current[n] = '\0';
    fclose(f);
    if (access(cred, R_OK) == 0 && strcmp(current, spp->sp_pwdp) == 0) return PAM_IGNORE;
  }

  char tmp[600];
  snprintf(tmp, sizeof tmp, "%s.tmp", cred);
  char *const argv[] = {"systemd-creds", "encrypt", "--name=" CRED_NAME, "--with-key=tpm2", "-", tmp, NULL};
  if (run_creds(argv, authtok, NULL, 0) != 0 || chmod(tmp, 0600) != 0 || rename(tmp, cred) != 0) {
    unlink(tmp);
    pam_syslog(pamh, LOG_WARNING, "could not seal the password for %s", user);
    return PAM_IGNORE;
  }
  if (write_file(hash, spp->sp_pwdp) != 0) pam_syslog(pamh, LOG_WARNING, "could not write %s", hash);

  pam_syslog(pamh, LOG_INFO, "sealed the password of %s for fingerprint logins", user);
  return PAM_IGNORE;
}

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
  (void)flags;
  if (argc != 1) return PAM_IGNORE;

  const char *user = NULL;
  if (pam_get_user(pamh, &user, NULL) != PAM_SUCCESS || !valid_user(user)) return PAM_IGNORE;

  if (strcmp(argv[0], "typed") == 0) return typed(pamh);
  if (strcmp(argv[0], "release") == 0) return release(pamh, user);
  if (strcmp(argv[0], "store") == 0) return store(pamh, user);
  return PAM_IGNORE;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
  (void)pamh;
  (void)flags;
  (void)argc;
  (void)argv;
  return PAM_IGNORE;
}
