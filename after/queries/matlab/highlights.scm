; highlights.scm

function_keyword: (identifier) @keyword
function_name: (identifier) @function
(function_definition end: (end) @keyword)
structure_keyword: (_) @keyword 

"true" @constant.builtin
"false" @constant.builtin

return_variable: (return_value) @type.builtin

(string) @string
