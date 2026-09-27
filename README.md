# tree-sitter-gohtml

Neovim 0.12+ 用的 Tree-sitter grammar／plugin：編輯以 HTML 為主、穿插 Go `html/template` 與 `text/template` 的檔案

預設只辨識 `.gohtml`，不會覆蓋 `.html`、`.tmpl`、`.gotmpl`

最低相容版本：Neovim 0.12（`vim.filetype.add`、`vim.treesitter.language.add`／`register`、`vim.treesitter.start`、`vim.pack`、`vim.system`）

## 技術判斷

比較過兩條路：

### 方案 A：沿用 `gotmpl` parser，把 HTML 注入 `text` 節點

參考 [ngalaiko/tree-sitter-go-template](https://github.com/ngalaiko/tree-sitter-go-template)（MIT）。主樹把 `{{...}}` 以外全部當成 `text`，再用：

```scheme
((text) @injection.content
 (#set! injection.language "html")
 (#set! injection.combined))
```

實際結果：

- `<h1>{{.Title}}</h1>`：主樹是 `text` + action + `text`；combined HTML 拼成 `<h1></h1>`，標籤可亮
- `<div class="{{.Class}}">`：`class="` 與 `"` 都是 `text`；拼成 `class=""` 後屬性洞可以亮，但主樹沒有 `attribute`
- `{{if}}<p>…</p>{{else}}…{{end}}`：if 包的是 `text` 不是 element；兩個分支的 HTML 被拼成同一份文件，分支標籤不平衡時 HTML 樹會 ERROR
- 控制結構包住多個元素：主樹看不到 element 層級，無法對「if 的 consequence 是哪個 element」做 query
- `<div {{if .X}}class="on"{{end}}>`：HTML 注入得到殘缺 tag。此失敗可重現，不是漏寫 injection

方案 A 不能只靠 `injections.scm` 覆蓋「控制結構包住 HTML」與「action 出現在 tag／attribute 內部」

### 方案 B（本專案採用）：專用 `gohtml` grammar

HTML 為主樹：`element`／`start_tag`／`attribute`／`comment`／`script_element`／`style_element`

Go action 是一等節點，可出現在文字旁、引號屬性值內、start tag 屬性列表中，以及以 `if`／`range`／`with`／`define`／`block` 包住一串 HTML `_node`

Template 運算式參考 MIT 的 tree-sitter-go-template；HTML 骨架參考 MIT 的 [tree-sitter-html](https://github.com/tree-sitter/tree-sitter-html)

已用 `tree-sitter test` 驗證需求六個片段（`test/corpus/required.txt`）以及 else-if、`with`、`define`／`block`／`template`、管線、tag 內 action、DOCTYPE／self-closing（`test/corpus/actions.txt`）

### 已知限制（已驗證）

1. 沒有 HTML 外部 scanner，不做隱式結束標籤（可省略的 `</p>`、`</li>`）
2. 不檢查開始／結束標籤名稱是否配對
3. 屬性值、`<script>`、`<style>`、HTML 註解裡的控制結構是扁平 action，不會在屬性裡再嵌 HTML element。文件本體的 `{{if}}…{{end}}` 會包住 element
4. `<script>`／`<style>` 主樹是 `raw_text` + action。JS／CSS 突顯靠可選注入，需要已安裝的 `javascript`／`css` parser；沒有那些 parser 時不假稱已做 JS 高亮
5. `raw_text` 在 `</s…` 處會停。腳本裡的 `</svg>` 可能提早結束 script／style 節點
6. `extras` 吃掉空白，所以 `{{$i}} {{$item}}` 中間沒有 `text` 節點


## 開發依賴

- C compiler（`cc`／`clang`／`gcc`）
- tree-sitter CLI（產生 parser、跑 corpus）：`npm install -g tree-sitter-cli`

不需要 lazy.nvim、packer.nvim、nvim-treesitter

## 從空目錄建置

```bash
cd tree-sitter-gohtml
tree-sitter generate
make compile
make test
make highlight-check
```

`make compile` 在 Linux 用 `-shared`，在 macOS 用 `-dynamiclib -undefined dynamic_lookup`，輸出都是 `parser/gohtml.so`

## 本機安裝（原生 packpath）

```bash
make install-plugin
# ~/.local/share/nvim/site/pack/gohtml/start/tree-sitter-gohtml
```

---

**只安裝 parser／queries**

> [!NOTE] 如果要最簡化，只要將指定的so檔案放到 `parser/<lang>.so` 下即可

```bash
make install
```

```lua
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    if pcall(vim.treesitter.start, args.buf) then -- start會抓filetype去找對應的lang並且也會language.add去加入相關lang的so檔案
      vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end
})
```

---

驗證:

開啟 `foo.gohtml` 後：

```vim
:echo &filetype
:lua =vim.treesitter.language.get_lang('gohtml')
:InspectTree
:Inspect
```

若尚未編譯 parser：`:TSBuildGohtml` 或 `make compile` 後重開 buffer

## 用 Neovim 0.12 `vim.pack` 安裝

```lua
vim.pack.add({
  { src = 'https://github.com/CarsonSlovoka/tree-sitter-gohtml' },
})
```

首次與更新後都要編譯

```vim
:TSBuildGohtml
```

或：

```bash
cd "$HOME/.local/share/nvim/site/pack/core/opt/tree-sitter-gohtml"
make compile
```

然後 `:restart`。更新用 `vim.pack.update()` 後再編譯一次

## 選擇性副檔名

```lua
vim.g.gohtml_extra_extensions = { 'tmpl', 'gotmpl' }
vim.g.gohtml_extra_patterns = {
  ['.*%.html%.tmpl'] = 'gohtml',
}

require('gohtml').setup({
  extra_extensions = { 'tmpl', 'gotmpl' },
  extra_patterns = { ['.*%.html%.tmpl'] = 'gohtml' },
})
```

不要把 `html` 加進去，除非確定要蓋掉所有 `.html`

## 確認突顯生效

1. `filetype` 是 `gohtml`
2. `:echo nvim_get_runtime_file('parser/gohtml.*', v:true)` 非空
3. `:echo nvim_get_runtime_file('queries/gohtml/highlights.scm', v:true)` 非空
4. `:InspectTree` 對 `<div class="{{.Class}}">` 看得到 `attribute` 裡的 `pipeline_action`；對 `{{if}}…{{else}}…{{end}}` 看得到 `if_action` 底下的 `element`

