#!/bin/sh
hyprctl clients | awk '/title: ./ { gsub("\t*title: *", ""); print}' | rofi -dmenu -i -font 'fira code nerd font 15' -show combi -icon-theme 'Papirus' -show-icons -matching fuzzy | xargs -I{} hyprctl dispatch focuswindow "title:{}"
