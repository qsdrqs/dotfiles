if version > 580
    hi clear
    if exists('syntax_on')
        syntax reset
    endif
endif

let g:colors_name='ghdark'

let g:github_colors = {
  \ "base0"        : ["#0d1117", 233],
  \ "base1"        : ["#171b22", 235],
  \ "base2"        : ["#21262d", 237],
  \ "base3"        : ["#89929b", 243],
  \ "base4"        : ["#ecf2f8", 252],
  \ "base5"        : ["#C9D1D9", 249],
  \ "red"          : ["#fa7970", 210],
  \ "orange"       : ["#faa356", 178],
  \ "green"        : ["#7ce38b", 114],
  \ "lightblue"    : ["#a2d2fb", 153],
  \ "blue"         : ["#79C0FF", 75],
  \ "purp"         : ["#cea5fb", 183],
  \ "none"         : ["NONE", "NONE"]
  \ }

" if doesn't support termguicolors or < 256 colors exit
if !(has('termguicolors') && &termguicolors) && !has('gui_running') && &t_Co != 256
  finish
endif

"########################################
" Terminal colors for NeoVim

if has('nvim')
    let g:terminal_color_0 = g:github_colors["base0"][0]
    let g:terminal_color_8 = g:github_colors["base3"][0]

    let g:terminal_color_1 = g:github_colors["red"][0]
    let g:terminal_color_9 = g:github_colors["red"][0]

    let g:terminal_color_2 = g:github_colors["green"][0]
    let g:terminal_color_10 = g:github_colors["green"][0]

    let g:terminal_color_3 = g:github_colors["orange"][0]
    let g:terminal_color_11 = g:github_colors["orange"][0]

    let g:terminal_color_4 = g:github_colors["blue"][0]
    let g:terminal_color_12 = g:github_colors["lightblue"][0]

    let g:terminal_color_5 = g:github_colors["purp"][0]
    let g:terminal_color_13 = g:github_colors["purp"][0]

    let g:terminal_color_6 = g:github_colors["blue"][0]
    let g:terminal_color_14 = g:github_colors["lightblue"][0]

    let g:terminal_color_7 = g:github_colors["base4"][0]
    let g:terminal_color_15 = g:github_colors["base5"][0]
endif

" Terminal colors for Vim
if has('*term_setansicolors')
    let g:terminal_ansi_colors = repeat([0], 16)

    let g:terminal_ansi_colors[0] = g:github_colors["base0"][0]
    let g:terminal_ansi_colors[8] = g:github_colors["base3"][0]

    let g:terminal_ansi_colors[1] = g:github_colors["red"][0]
    let g:terminal_ansi_colors[9] = g:github_colors["red"][0]

    let g:terminal_ansi_colors[2] = g:github_colors["green"][0]
    let g:terminal_ansi_colors[10] = g:github_colors["green"][0]

    let g:terminal_ansi_colors[3] = g:github_colors["orange"][0]
    let g:terminal_ansi_colors[11] = g:github_colors["orange"][0]

    let g:terminal_ansi_colors[4] = g:github_colors["blue"][0]
    let g:terminal_ansi_colors[12] = g:github_colors["lightblue"][0]

    let g:terminal_ansi_colors[5] = g:github_colors["purp"][0]
    let g:terminal_ansi_colors[13] = g:github_colors["purp"][0]

    let g:terminal_ansi_colors[6] = g:github_colors["blue"][0]
    let g:terminal_ansi_colors[14] = g:github_colors["lightblue"][0]

    let g:terminal_ansi_colors[7] = g:github_colors["base4"][0]
    let g:terminal_ansi_colors[15] = g:github_colors["base5"][0]
endif

if !exists("g:gh_color")
    let g:gh_color = "hard"
endif

if g:gh_color ==# "soft"
    let g:github_colors["base0"] = g:github_colors["base1"]
    let g:github_colors["base1"] = g:github_colors["base2"]
    let g:github_colors["base2"] = ["#30353c", 238]
endif

"########################################
" funcs

function! s:ghhl(group, guifg, ...)
    " Arguments: group, guifg, guibg, style

    let fg = g:github_colors[a:guifg]

    if a:0 >= 1
        let bg = g:github_colors[a:1]
    else
        let bg = g:github_colors["none"]
    endif

    if a:0 >= 2
        let style = a:2
    else
        let style = "NONE"
    endif

    let hi_str = [ "hi", a:group,
            \ 'guifg=' . fg[0], "ctermfg=" . fg[1],
            \ 'guibg=' . bg[0], "ctermbg=" . bg[1],
            \ 'gui=' . style, "cterm=" . style
            \ ]

    execute join(hi_str, ' ')
endfunction

"########################################
" clear any previous highlighting and syntax

let s:t_Co = exists('&t_Co') && !empty(&t_Co) && &t_Co > 1 ? &t_Co : 2

"########################################
" set the colors
"
call s:ghhl("GhBase0", "base0")
call s:ghhl("GhBase1", "base1")
call s:ghhl("GhBase2", "base2")
call s:ghhl("GhBase3", "base3")
call s:ghhl("GhBase4", "base4")
call s:ghhl("GhBase5", "base5")
call s:ghhl("GhRed", "red")
call s:ghhl("GhPurpUnder", "purp", "none", "undercurl")
call s:ghhl("GhOrange", "orange")
call s:ghhl("GhLightBlue", "lightblue")
call s:ghhl("GhBlue", "blue")
call s:ghhl("GhBlueItalic", "blue", "none", "italic")
call s:ghhl("GhPurp", "purp")
call s:ghhl("GhGreen", "green")
call s:ghhl("GhUnder", "none", "none", "underline")
call s:ghhl("GhBold", "none", "none", "bold")
call s:ghhl("GhItalic", "none", "none", "italic")

call s:ghhl("Cursor", "base4", "none", "reverse")
call s:ghhl("iCursor", "base0", "red")
call s:ghhl("vCursor", "base0", "purp")
call s:ghhl("CursorColumn", "none", "base1")
call s:ghhl("CursorLine", "none", "base1")
call s:ghhl("CursorLineNr", "lightblue", "base0")
"call s:ghhl("DiffAdd", "green", "base0")
"call s:ghhl("DiffChange", "orange", "base0")
"call s:ghhl("DiffDelete", "red", "base0")
"call s:ghhl("DiffText", "orange", "base0")

"call s:ghhl("ErrorMsg", "red", "base1")
call s:ghhl("Error", "none", "red")
call s:ghhl("Folded", "blue", "base1")
" call s:ghhl("MatchParen", "none", "base3")
hi! MatchParen guibg=#1A3B25
call s:ghhl("Normal", "base5", "base0")
call s:ghhl("NormalFloat", "base4", "base1")
call s:ghhl("Pmenu", "base4", "base0")
call s:ghhl("PmenuThumb", "base1", "base5")
call s:ghhl("PmenuSel", "base4", "base2", "bold")
"call s:ghhl("Search", "base0", "base5")
call s:ghhl("SignColumn", "none", "base0")
call s:ghhl("StatusLine", "base5", "base2")
call s:ghhl("StatusLineNC", "base3", "base1")
call s:ghhl("Todo", "base4", "base0")
call s:ghhl("VertSplit", "base1", "base1")
call s:ghhl("Visual", "none", "base0", "reverse")
call s:ghhl("WarningMsg", "orange", "base1")

"########################################
" links

hi! link Boolean Constant
hi! link Character Constant
"hi! link Comment GhBase3
hi! link Conceal GhBase3
hi! link Conditional Statement
hi! link Constant GhLightBlue
hi! link Debug Special
hi! link Define PreProc
hi! link Delimiter GhBase5
hi! link Directory GhBlue
hi! link Exception Statement
hi! link Float Number
hi! link FunctionDef Function
hi! link Function GhPurp
if has('nvim')
  hi! Identifier guifg=#C9D1D9 guibg=none
else
  hi! link Identifier GhBlue
endif
hi! link Include Statement
hi! link IncSearch Search
hi! link Keyword GhRed
hi! link Label GhBlue
hi! link LibraryFunc Function
hi! link LibraryIdent Identifier
hi! link LibraryType Type
hi! link LineNr GhBase3
hi! link LocalFunc Function
hi! link LocalIdent Identifier
hi! link LocalType Type
hi! link Macro PreProc
hi! link ModeMsg GhBase4
hi! link MoreMsg GhBase4
hi! link MsgArea GhBase4
hi! link Noise Delimiter
"hi! link NonText GhBase3
hi! link NonText Ignore
hi! link Number GhBlue
hi! link Operator GhBlue
hi! link PreCondit PreProc
"hi! link PreProc GhBase5
hi! link Question GhBase4
hi! link Quote StringDelimiter
hi! link Repeat GhPurp
hi! link Searchlight Search
hi! link SignifySignAdd Signify
hi! link SignifySignChange Signify
hi! link SignifySignDelete Signify
hi! link SpecialChar Special
"hi! link Special GhLightBlue
"hi! link SpecialKey GhBase3
"hi! link SpecialKey Ignore
hi! link Statement GhRed
hi! link StatusLineTermNC StatusLineNC
hi! link StatusLineTerm StatusLine
hi! link StorageClass Statement
hi! link String Constant
hi! link StringDelimiter String
hi! link Structure Statement
hi! link TabLineFill StatusLineNC
hi! link TabLineSel StatusLine
hi! link TabLine StatusLineNC
hi! link Tag Special
hi! link Terminal Normal
hi! link Title markdownH1
hi! link Type GhRed

" ALE

hi! link ALEVirtualTextError ErrorMsg
hi! link ALEVirtualTextWarning WarningMsg

" bib

hi! link bibEntryKw LibraryIdent
hi! link bibKey IdentifierDef
hi! link bibType LibraryType

" C

hi! link cDefine Keyword

" Coc

hi! link CocErrorSign ErrorMsg
hi! link CocWarningSign WarningMsg
hi! link CocInfoSign GhLightBlue
hi! CocHintSign guifg=#8B949E guibg=#262C32
hi! link CocInlayHint CocHintSign
hi! link CocHintVirtualText CocHintSign
hi! link CocErrorFloat ErrorMsg
hi! link CocWarningFloat WarningMsg
hi! link CocInfoFloat GhLightBlue
hi! link CocHintFloat GhPurp
hi! link CocDiagnosticsError ErrorMsg
hi! link CocDiagnosticsWarning WarningMsg
hi! link CocDiagnosticsInfo GhLightBlue
hi! link CocDiagnosticsHint GhPurp
hi! link CocSelectedText GhRed
hi! link CocCodeLens GhBase3
hi! link Property GhBlue
hi! link CocSemProperty Property
hi! link CocSemClass GhOrange
hi! link CocSemStruct GhOrange
hi! Parameter guifg=#ef9062
hi! TypeParameter guifg=#faa356 gui=bold
hi! link CocSemTypeParameter TypeParameter
hi! link CocSemParameter Parameter

call s:ghhl("CocErrorHighlight", "none", "none", "undercurl,bold")
hi! link CocWarningHighlight CocErrorHighlight
hi! link CocInfoHighlight CocErrorHighlight
hi! link CocHintHighlight CocErrorHighlight

" Nvim LSP
hi! link DiagnosticUnderlineError ErrorMsg
hi! link DiagnosticUnderlineWarn WarningMsg
hi! link DiagnosticUnderlineInfo GhLightBlue
hi! link DiagnosticUnderlineHint GhBase3

hi! DiagnosticError guifg=#fa7970 guibg=NONE guisp=#Fa7970
hi! DiagnosticWarn guifg=#faa356 guibg=NONE guisp=#faa356
hi! link DiagnosticInfo GhLightBlue
hi! link DiagnosticHint GhBase3

hi! link LspInlayHint CocInlayHint

" CSS

hi! link cssAtRule Keyword
hi! link cssAtKeyword Keyword
hi! link cssMediaProp GhBlue
hi! link cssBoxProp GhBlue
hi! link cssFlexibleBoxProp cssBoxProp
hi! link cssPositioningProp cssBoxProp
hi! link cssBackgroundProp cssBoxProp
hi! link cssBorderProp cssBoxProp
hi! link cssIEUIProp cssBoxProp
hi! link cssFontDescriptorProp cssBoxProp
hi! link cssTextProp cssBoxProp
hi! link cssCustomProp GhWhite
hi! link cssUIProp cssBoxProp
hi! link cssTransitionProp cssBoxProp
hi! link cssCascadeProp cssBoxProp
hi! link cssColorProp cssBoxProp
hi! link cssListProp cssBoxProp
hi! link cssPageProp cssBoxProp
hi! link cssAttrComma GhWhite
hi! link cssBackgroundAttr cssBoxAttr
hi! link cssBorderAttr cssBoxAttr
hi! link cssBoxAttr Normal
hi! link cssBraces cssNoise
hi! link cssClassName LocalIdent
hi! link cssColor LightBlue
hi! link cssCommonAttr cssBoxAttr
hi! link cssFlexibleBoxAttr cssBoxAttr
hi! link cssFunction NONE
hi! link cssIdentifier LocalIdent
hi! link cssMediaType Normal
hi! link cssMultiColumnAttr cssBoxAttr
hi! link cssNoise Normal
hi! link cssPositioningAttr cssBoxAttr
hi! link cssProp LibraryType
hi! link cssPseudoClassId LibraryIdent
hi! link cssSelectorOp Operator
hi! link cssTableAttr cssBoxAttr
hi! link cssTagName htmlTagName
hi! link cssTextAttr cssBoxAttr
hi! link cssTransitionAttr cssBoxAttr
hi! link cssUIAttr cssBoxAttr
hi! link cssUnitDecorators Normal

" diff

hi! Added guifg=#7ce38b guibg=#0d1117
hi! Removed guifg=#fa7970 guibg=#0d1117
hi! Changed guifg=#faa356 guibg=#0d1117
hi! link diffAdded Added
hi! link diffRemoved Removed
hi! link diffChanged Changed
hi! link diffBDiffer WarningMsg
hi! link diffCommon WarningMsg
hi! link diffDiffer WarningMsg
hi! link diffFile Directory
hi! link diffIdentical WarningMsg
hi! link diffIndexLine Number
hi! link diffIsA WarningMsg
hi! link diffNoEOL WarningMsg
hi! link diffOnly WarningMsg

" Git commit

hi! link gitcommitHeader Todo
hi! link gitcommitOverflow Error
hi! link gitcommitSummary Title

" go

hi! link goBuiltins Function
hi! link goField LocalIdent
hi! link goFunctionCall LibraryFunc
hi! link goFunction FunctionDef
hi! link goLabel Keyword
hi! link goType Normal
hi! link goVarAssign LocalIdent
hi! link goVarDefs IdentifierDef

" Vim help

hi! link helpCommand helpExample
hi! link helpExample markdownCode
hi! link helpHeadline Title
hi! link helpHyperTextEntry Comment
hi! link helpHyperTextJump Underlined
hi! link helpSectionDelim Ignore
hi! link helpURL helpHyperTextJump
hi! link helpVim Title

" HTML

hi! link htmlArg Special
hi! link htmlLink Underlined
hi! link htmlSpecialTagName htmlTagName
hi! link htmlTag Identifier
hi! link htmlTagName GhGreen

" java

hi! link javaScriptBraces Normal
hi! link javaScriptFunction Keyword
hi! link javaScriptIdentifier Keyword

" jinja

hi! link jinjaBlockName Typedef
hi! link jinjaFilter LibraryFunc
hi! link jinjaNumber Number
hi! link jinjaOperator Operator
hi! link jinjaRawDelim PreProc
hi! link jinjaSpecial Keyword
hi! link jinjaString String
hi! link jinjaTagDelim Delimiter
hi! link jinjaVarDelim Delimiter

" JavaScript

hi! link jsBuiltins LibraryFunc
hi! link jsClassDefinition Typedef
hi! link jsDestructuringBraces jsFuncBraces
hi! link jsDomErrNo LibraryIdent
hi! link jsDomNodeConsts LibraryIdent
hi! link jsDot Normal
hi! link jsExceptions LibraryType
hi! link jsFuncArgCommas jsFuncParens
hi! link jsFuncName Function
hi! link jsFuncParens Normal
hi! link jsFunction jsStatement
hi! link jsGlobalNodeObjects jsFuncName
hi! link jsGlobalObjects Normal
hi! link jsIfElseBraces jsFuncBraces
hi! link jsNoise jsFuncBraces
hi! link jsObjectBraces jsFuncBraces
hi! link jsObjectKey jsObjectProp
hi! link jsObjectProp LocalIdent
hi! link jsObjectSeparator jsFuncBraces
hi! link jsOperatorKeyword jsStatement
hi! link jsParensIfElse jsFuncBraces
hi! link jsParens jsFuncBraces
hi! link jsThis jsStatement
hi! link jsVariableDef IdentifierDef
hi! link jsBooleanFalse GhBlue
hi! link jsBooleanTrue jsBooleanFalse
hi! link jsRepeat Keyword
hi! link jsArrowFunction GhBlue
hi! link jsTernaryIfOperator jsDot

" markdown

call s:ghhl("markdownH1", "blue", "none", "bold")
hi! link markdownH2 markdownH1
hi! link markdownH3 markdownH1
hi! link markdownH4 markdownH1
hi! link markdownH5 markdownH1
hi! link markdownCode GhLightBlue
hi! link markdownCodeDelimiter GhLightBlue
hi! link markdownInlineCode markdownCode
hi! link markdownListMarker GhRed
hi! link markdownLinkText GhPurpUnder
hi! link markdownUrl GhBlueItalic
hi! link markdownLinkUrl markdownUrl
hi! link markdownBold GhBold
hi! link markdownItalic GhItalic
hi! link SpellBad ErrorMsg
hi! link SpellCap WarningMsg
hi! link SpellLocal WarningMsg
hi! link SpellRare GhLightBlue

" python
hi! link pythonClass GhOrange
hi! link pythonRepeat Keyword
hi! link pythonBoolean GhBlue
hi! link pythonBuiltin GhBlue
hi! link pythonBuiltinType GhBase5
hi! link pythonClassVar GhBase5
hi! link pythonOperator NONE
hi! link pythonOperator GhBlue
hi! link pythonRun GhBase3
hi! link pythonDecorator GhPurp

" Rust

hi! link rsForeignConst LibraryIdent
hi! link rsForeignFunc LibraryFunc
hi! link rsForeignType LibraryType
hi! link rsFuncDef FunctionDef
hi! link rsIdentDef IdentifierDef
hi! link rsLibraryConst LibraryIdent
hi! link rsLibraryFunc LibraryFunc
hi! link rsLibraryType LibraryType
hi! link rsLifetimeDef IdentifierDef
hi! link rsSpecialLifetime LibraryIdent
hi! link rsUserConst LocalIdent
hi! link rsUserFunc LocalFunc
hi! link rsUserLifetime LocalIdent
hi! link rsUserMethod LibraryFunc
hi! link rsUserType LocalType
hi! link rustAttribute Normal
hi! link rustCommentLineDoc rustCommentLine
hi! link rustDerive rustAttribute
hi! link rustDeriveTrait rustAttribute
hi! link rustEnumVariant GhBlue
hi! link rustIdentifier Function
hi! link rustIdentifier Normal
hi! link rustLifetime GhPurp
hi! link rustMacro GhBlue
hi! link rustModPath Normal
hi! link rustModPathSep Keyword
hi! link rustOperator Keyword
hi! link rustQuestionMark Normal
hi! link rustSelf GhBlue

" SCSS

hi! link scssAttribute cssNoise
hi! link scssInclude Keyword
hi! link scssMixin Keyword
hi! link scssMixinName LocalFunc
hi! link scssMixinParams cssNoise
hi! link scssSelectorName cssClassName
hi! link scssVariableAssignment Operator
hi! link scssVariableValue Operator

" shell

hi! link shAlias shVariable
hi! link shCaseLabel Type
hi! link shDerefPPS Keyword
hi! link shDeref shVariable
hi! link shDerefSimple shVariable
hi! link shDoubleQuote shQuote
hi! link shEcho GhBlue
hi! link shEcho Normal
hi! link shFunctionKey Keyword
hi! link shFunctionOne Normal
hi! link shOperator shParen
hi! link shOption shFunctionOne
hi! link shParen Normal
hi! link shQuote Constant
hi! link shRange shParen
hi! link shRedir Keyword
hi! link shSetList shFunctionOne
hi! link shSnglCase shParen
hi! link shStatement Keyword
hi! link shVariable Normal
hi! link shWrapLineOperator shParen

" swift

hi! link swiftFuncDef FunctionDef
hi! link swiftIdentDef IdentifierDef
hi! link swiftLibraryFunc LibraryFunc
hi! link swiftLibraryProp LibraryIdent
hi! link swiftLibraryType LibraryType
hi! link swiftUserFunc LocalFunc
hi! link swiftUserProp LocalIdent
hi! link swiftUserType LocalType

" typescript

hi! link typescriptArrayMethod LibraryFunc
hi! link typescriptArrowFunc Operator
hi! link typescriptAssign Operator
hi! link typescriptBinaryOp Operator
hi! link typescriptBOM LibraryType
hi! link typescriptBOMWindowCons LibraryType
hi! link typescriptBOMWindowMethod LibraryFunc
hi! link typescriptBOMWindowProp LibraryType
hi! link typescriptBraces Delimiter
hi! link typescriptCall NONE
hi! link typescriptClassHeritage Type
hi! link typescriptClassName TypeDef
hi! link typescriptDOMDocMethod LibraryFunc
hi! link typescriptDOMDocProp LibraryIdent
hi! link typescriptDOMEventCons LibraryType
hi! link typescriptDOMEventMethod LibraryFunc
hi! link typescriptDOMEventMethod LibraryFunc
hi! link typescriptDOMEventProp LibraryIdent
hi! link typescriptDOMEventTargetMethod LibraryFunc
hi! link typescriptDOMNodeMethod LibraryFunc
hi! link typescriptDOMStorageMethod LibraryIdent
hi! link typescriptEndColons Delimiter
hi! link typescriptExport Keyword
hi! link typescriptFuncName FunctionDef
hi! link typescriptFuncTypeArrow typescriptArrowFunc
hi! link typescriptGlobal typescriptPredefinedType
hi! link typescriptIdentifier Keyword
hi! link typescriptInterfaceName Typedef
hi! link typescriptMember LocalFunc
hi! link typescriptObjectLabel LocalIdent
hi! link typescriptOperator Keyword
hi! link typescriptParens Delimiter
hi! link typescriptPredefinedType LibraryType
hi! link typescriptTypeAnnotation Delimiter
hi! link typescriptTypeReference typescriptUserDefinedType
hi! link typescriptUserDefinedType LocalType
hi! link typescriptVariableDeclaration IdentifierDef
hi! link typescriptVariable Keyword

" vim

hi! link vimAutoCmdSfxList LibraryType
hi! link vimAutoEventList LocalIdent
hi! link vimCmdSep vimSep
hi! link vimCommand Keyword
hi! link vimCommentTitle SpecialComment
hi! link vimContinue vimSep
hi! link vimExecute LocalFunc
hi! link vimFuncName LibraryFunc
hi! link vimFunction FunctionDef
hi! link vimFuncVar Normal
hi! link vimGroup vimHiGroup
hi! link vimHiBang vimOper
hi! link vimHighlight Operator
hi! link vimHiGroup GhOrange
hi! link vimIsCommand vimVar
hi! link vimLet vimOper
hi! link vimMapModKey vimNotation
hi! link vimNotation LibraryType
hi! link vimOper Keyword
hi! link vimOperParen Normal
hi! link vimOption LibraryIdent
hi! link vimParenSep vimSep
hi! link vimSep Normal
hi! link vimUserFunc LocalFunc
hi! link vimVar Normal
hi! link vimUserAttrb Identifier
hi! link vimUserCommand vimUserAttrb
hi! link vimPatSepR GhGreen
hi! link vimPatRegion vimPatSepR
hi! link vimSynNotPatRange vimPatSepR
hi! link vimSynKeyRegion Keyword
hi! link vimSynType Identifier
hi! link vimSyncMatch vimSynType

hi! link VisualNOS Visual
hi! link Whitespace Ignore

" yaml

hi! link yamlKey GhGreen
hi! link yamlConstant GhBlue

" nerdtree

hi! link NERDTreeDir GhBlue
hi! link NERDTreeDirSlash GhBlue
hi! link NERDTreeOpenable GhRed
hi! link NERDTreeClosable GhGreen
hi! link NERDTreeFile GhBase5
hi! link NERDTreeExecFile GhOrange
hi! link NERDTreeCWD GhPurp
hi! link NERDTreeUp GhBase3
hi! link NERDTreeHelp GhBase5

" toml

hi! link tomlKey GhBase4
hi! link tomlKeyValueArray GhBase4
hi! link tomlTable GhPurp

" json

hi! link jsonBoolean GhBlue
hi! link jsonKeywordMatch GhBase4
hi! link jsonString String
hi! link jsonKeyword jsonString
hi! link jsonQuote jsonString

"custom
hi! Comment guifg=#8B949E
hi! Function guifg=#D2A8FF
hi! Repeat guifg=#FA7970
hi! Define guifg=#FA7970
hi! Todo guibg=#FFBD2A guifg=#FFFFFF
hi! Whitespace guifg=#677586
hi! Visual gui=bold guibg=#163356
hi! Search  guibg=#4d4b31 guifg=NONE
"hi! Search  guibg=#3c3b26 guifg=NONE
hi! link specialkey Whitespace
hi! Type guifg=#FA7970 gui=NONE
hi! Class guifg=#FFA657 gui=NONE
hi! link PreProc GhBlue
hi! link Operator Repeat
hi! link NonText Whitespace
hi IncSearch term=reverse cterm=reverse ctermfg=193 ctermbg=16 gui=reverse guifg=#C4BE89 guibg=#000000
hi! link Special Preproc
if has('nvim')
  hi! PmenuSel guifg=NONE guibg=#393F47
endif
hi! link helpSectionDelim Comment
if has('nvim')
hi! ErrorMsg guifg=#fa7970 guibg=NONE guisp=#Fa7970 gui=undercurl
hi! WarningMsg guifg=#faa356 guibg=NONE guisp=#faa356 gui=undercurl
hi! DiffChange guifg=NONE guibg=#462D10
hi! DiffAdd guifg=NONE guibg=#104731
hi! DiffDelete guifg=NONE guibg=#4C111F
hi! DiffText guifg=NONE guibg=#7A5614
endif
hi! Context guibg=#0D2341
hi! FileName guifg=#C4CBD7
" highlight FloatBorder guifg=#525869 guibg=#1F2335
hi! link FloatBorderClear GhBase4
hi! TextSuccess guifg=#7ce38b
hi! BoldSuccess guifg=#7ce38b gui=bold
hi! link TextInfo GhBlue
hi! BoldInfo guifg=#a2d2fb gui=bold
call s:ghhl("FoldColumn", "base3", "base0")

" under cursor
hi! UnderCursorText guibg=#1A3B25 gui=none
hi! UnderCursorRead guibg=#424852 gui=none
hi! UnderCursorWrite guibg=#2A3037 gui=none

" nvim cmp
highlight! CmpItemAbbrDeprecated guibg=NONE gui=strikethrough guifg=#808080
" blue
highlight! CmpItemAbbrMatch guibg=NONE guifg=#569CD6 gui=bold
highlight! CmpItemAbbrMatchFuzzy guibg=NONE guifg=#569CD6 gui=bold
highlight! CmpItemMenuDefault guifg=#ecf2f8

" light blue
highlight! CmpItemKindVariable guibg=NONE guifg=#9CDCFE
highlight! CmpItemKindInterface guibg=NONE guifg=#9CDCFE
highlight! CmpItemKindEnum guibg=NONE guifg=#9CDCFE

" cyan
highlight! CmpItemKind guibg=NONE guifg=#8Cf8F7

" pink
highlight! CmpItemKindFunction guibg=NONE guifg=#C586C0
highlight! CmpItemKindMethod guibg=NONE guifg=#C586C0
" front
highlight! CmpItemKindText guibg=NONE guifg=#D4D4D4
highlight! CmpItemKindProperty guibg=NONE guifg=#D4D4D4
highlight! CmpItemKindUnit guibg=NONE guifg=#D4D4D4
" yellow
highlight! CmpItemKindClass guibg=NONE guifg=#FFC33E
highlight! CmpItemKindStruct guibg=NONE guifg=#FFC33E
highlight! CmpItemKindTabNine guibg=NONE guifg=#FFC33E
highlight! CmpItemKindKeyword guibg=NONE guifg=#FF5252

" blink.cmp
highlight! link BlinkCmpLabelDeprecated CmpItemAbbrDeprecated
highlight! link BlinkCmpLabelMatch CmpItemAbbrMatch
highlight! link BlinkCmpLabel CmpItemMenuDefault

highlight! link BlinkCmpKindVariable CmpItemKindVariable
highlight! link BlinkCmpKindInterface CmpItemKindInterface
highlight! link BlinkCmpKindEnum CmpItemKindEnum

highlight! link BlinkCmpKind CmpItemKind

highlight! link BlinkCmpKindFunction CmpItemKindFunction
highlight! link BlinkCmpKindMethod CmpItemKindMethod

highlight! link BlinkCmpKindText CmpItemKindText
highlight! link BlinkCmpKindProperty CmpItemKindProperty
highlight! link BlinkCmpKindUnit CmpItemKindUnit

highlight! link BlinkCmpKindClass CmpItemKindClass
highlight! link BlinkCmpKindStruct CmpItemKindStruct
highlight! link BlinkCmpKindTabNine CmpItemKindTabNine
highlight! link BlinkCmpKindKeyword CmpItemKindKeyword

highlight! BlinkCmpDoc guifg=None guibg=NONE

autocmd Filetype vim,lua highlight! link Type Class

highlight IndentBlanklineContextStart1 guisp=#79C0FF gui=underline
highlight IndentBlanklineContextStart2 guisp=#56D364 gui=underline
highlight IndentBlanklineContextStart3 guisp=#FFA657 gui=underline
highlight IndentBlanklineContextStart4 guisp=#FA7970 gui=underline
highlight IndentBlanklineContextStart5 guisp=#FF9BCE gui=underline
highlight IndentBlanklineContextStart6 guisp=#D2A8FF gui=underline

highlight! Color1 guifg=#79C0FF
highlight! Color2 guifg=#56D364
highlight! Color3 guifg=#FFA657
highlight! Color4 guifg=#FA7970
highlight! Color5 guifg=#FF9BCE
highlight! Color6 guifg=#D2A8FF

" hlargs
highlight Hlargs guifg=#ef9062

" copilot
hi! CopilotSuggestion guifg=#808080
hi! link CopilotAnnotation MoreMsg
