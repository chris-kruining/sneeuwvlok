def RESET: "0";
def BOLD: "1";
def DIM: "2";
def ITALIC: "3";
def UNDERLINE: "4";
def BLINKING: "5";
def INVERSE: "7";
def HIDDEN: "8";
def STRIKETHROUGH: "9";
def RESET_FONT: "22";

def BLACK: 0;
def RED: 1;
def GREEN: 2;
def YELLOW: 3;
def BLUE: 4;
def MAGENTA: 5;
def CYAN: 6;
def WHITE: 7;
def DEFAULT: 9;

def foreground(color): 30 + color;
def background(color): 40 + color;
def bright(color): 60 + color;

def escape(options):
    (if ((options|type) == "array") then options else [options] end) as $o
    | "\u001b[\($o | map(tostring) | join(";"))m";

def style(options): escape(options) + . + escape([RESET]);

def to_title:
    (.|ascii_upcase) as $str
    | escape([BOLD, foreground(BLACK), background(WHITE)]) + " " + $str + " " + escape([RESET]);
