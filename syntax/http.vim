" Basic syntax highlighting for .http/.rest files (nvim-restclient).
if exists("b:current_syntax")
  finish
endif

syntax case match

syntax match restclientComment "^\s*#.*$"
syntax match restclientComment "^\s*//.*$"
syntax match restclientSeparator "^\s*###.*$"
syntax match restclientVariableDef "^@[A-Za-z0-9_.-]\+\s*="
syntax match restclientVariableRef "{{\s*[A-Za-z0-9_.-]\+\s*}}"

syntax match restclientMethod "^\(GET\|POST\|PUT\|DELETE\|PATCH\|HEAD\|OPTIONS\|TRACE\|CONNECT\)\>"
syntax match restclientHeaderName "^[A-Za-z][A-Za-z0-9-]*\ze\s*:" nextgroup=restclientHeaderColon
syntax match restclientHeaderColon ":" contained

highlight default link restclientComment Comment
highlight default link restclientSeparator PreProc
highlight default link restclientVariableDef Identifier
highlight default link restclientVariableRef Macro
highlight default link restclientMethod Keyword
highlight default link restclientHeaderName Type
highlight default link restclientHeaderColon Delimiter

let b:current_syntax = "http"
