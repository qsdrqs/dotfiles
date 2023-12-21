hi clear
if exists('syntax_on')
    syntax reset
endif

hi NvimLightRed guifg=#ffc0b9
hi Orange guifg=#ffa500
hi NvimLightYellow guifg=#fce094
hi NvimLightGreen guifg=#b3f6c0
hi NvimLightBlue guifg=#a6dbff
hi NvimLightMagenta guifg=#ffcaff

highlight! link Color1 NvimLightRed
highlight! link Color2 Orange
highlight! link Color3 NvimLightYellow
highlight! link Color4 NvimLightGreen
highlight! link Color6 NvimLightBlue
highlight! link Color5 NvimLightMagenta

hi! DiffAdd guifg=None
hi! DiffDelete guifg=None
hi! DiffText guifg=None

let colors_name = "default_plus"
