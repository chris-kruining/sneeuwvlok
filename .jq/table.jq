import "format" as _ {search:"./"};

def n_max(limit):
    if . > limit then limit else . end;

def n_min(limit):
    if . < limit then limit else . end;

def pad_right(width):
    (. | tostring) as $s
    | ($s | length) as $l
    | ((width - $l) | n_min(0)) as $w
    | ($s + (" " * $w));

def to_cells(sizes; fn):
    to_entries
    | map(
        (sizes[.key]) as $size
        | (" " + .value)
        | pad_right($size + 2)
        | fn // .
    );

def to_cells(sizes): to_cells(sizes; null);

def to_line(left; joiner; right):
    [left, .[1], (.[1:] | map([joiner, .]) ), right] | flatten | join("");

def create(data; header_callback; cell_callback):
    (data[0] | to_entries | map(.key)) as $keys
    | ([$keys]) as $header
    | (data | map(to_entries | map(.value))) as $rows
    | ($header + $rows) as $cells
    | (
        $keys # Use keys so that we have an array of the correct size
        | to_entries
        | map(
            (.key) as $i
            | $cells
            | map(.[$i] | length)
            | max
        )
    ) as $column_sizes
    | (
        [
            ($column_sizes | map("═" * (. + 2)) | to_line("╔"; "╤"; "╗")),
            ($keys | to_cells($column_sizes; header_callback) | to_line("║"; "│"; "║")),
            ($rows | map([
                ($column_sizes | map("─" * (. + 2)) | to_line("╟"; "┼"; "╢")),
                (. | to_cells($column_sizes; cell_callback) | to_line("║"; "│"; "║"))
            ])),
            ($column_sizes | map("═" * (. + 2)) | to_line("╚"; "╧"; "╝"))
        ]
        | flatten
        | join("\n")
    );

def create(data; header_callback): create(data; header_callback; null);
def create(data): create(data; _::style(_::BOLD); null);
