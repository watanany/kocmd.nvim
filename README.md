# kocmd.nvim

コマンド出力パネルのトグル管理プラグイン。

## 機能

- コマンドごとにスプリット/フローティングウィンドウをトグル表示
- タブごとに状態を保持（バッファ内容を維持したまま開閉可能）
- ウィンドウ位置: `top` / `bottom` / `left` / `right` / `float`

## セットアップ

```lua
require("kocmd").setup({
  commands = {
    term = {
      cmd = "terminal",
      position = "bottom",
      size = 20,
    },
    lazygit = {
      cmd = function()
        vim.fn.termopen("lazygit")
      end,
      position = "float",
      size = { width = 0.9, height = 0.9 },
    },
  },
})
```

### コマンド設定

| キー       | 説明                              | デフォルト   |
| ---------- | --------------------------------- | ------------ |
| `cmd`      | 実行コマンド（文字列 or 関数）    | 必須         |
| `position` | ウィンドウ位置                    | `"bottom"`   |
| `size`     | サイズ（行/列数、floatは比率も可）| `20`         |

## 使い方

```vim
:Kocmd term
:Kocmd lazygit
```

```lua
vim.keymap.set("n", "<Leader>ot", function() require("kocmd").toggle("term") end)
```
