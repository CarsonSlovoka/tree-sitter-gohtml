; Optional host-language highlighting inside raw <script> / <style> bodies.
; These injections only apply when a javascript / css parser is available on
; runtimepath. Template actions inside the body stay in the gohtml tree and
; are not part of the injected range.
;
; Combined injection is not used here because each raw_text node is already a
; contiguous span. Actions between raw_text chunks remain gohtml.

((script_element
  (raw_text) @injection.content)
  (#set! injection.language "javascript"))

((style_element
  (raw_text) @injection.content)
  (#set! injection.language "css"))
