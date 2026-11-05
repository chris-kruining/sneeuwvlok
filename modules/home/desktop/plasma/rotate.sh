# usage: plasma-wallpaper-rotate [name]
# Applies a wallpaper together with the colour scheme, folder colour and terminal palette made from it. Without a
# name it takes today's from the rotation, so every day is the next one in the list
themes="@themes@/share/wallpaper-themes"
mapfile -t names < "$themes/order"

if [ $# -gt 0 ]; then
  name=$1
  if [ ! -d "$themes/$name" ]; then
    echo "unknown wallpaper '$name', pick one of: ${names[*]}" >&2
    exit 1
  fi
else
  day=$(( $(date -d "$(date +%F) UTC" +%s) / 86400 ))
  name=${names[day % ${#names[@]}]}
fi

dir="$themes/$name"
image=$(readlink -f "$dir/image")
echo "applying $name"

plasma-apply-wallpaperimage "$image"
kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General \
  --key Image "file://$image"

# both refuse to apply what's already set, which is fine, so their exit codes don't matter
plasma-apply-colorscheme "Wallpaper-$name" || true
@changeicons@ "Papirus-Accent-$(cat "$dir/folder")" || true

ln -sfn "$dir/ghostty" "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/wallpaper"
systemctl --user reload app-com.mitchellh.ghostty.service 2>/dev/null || true
