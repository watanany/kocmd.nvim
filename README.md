# kocmd.nvim

コマンド出力パネルのトグル管理プラグイン。

## 機能

- コマンドごとにスプリット/フローティングウィンドウをトグル表示
- タブごとに状態を保持（バッファ内容を維持したまま開閉可能）
- ウィンドウ位置: `top` / `bottom` / `left` / `right` / `float`

## セットアップ (lazy.nvim)

```lua
{
  "watanany/kocmd.nvim",
  keys = {
    { "<Leader>ot", function() require("kocmd").toggle("shell") end, desc = "Toggle shell" },
    { "<Leader>og", function() require("kocmd").toggle("lazygit") end, desc = "Toggle lazygit" },
    { "<Leader>od", function() require("kocmd").toggle("lazydocker") end, desc = "Toggle lazydocker" },
    { "<Leader>oc", function() require("kocmd").toggle("claude") end, desc = "Toggle claude" },
  },
  opts = {
    commands = {
      shell = {
        cmd = function() vim.cmd("term") end,
        position = "bottom",
        size = 20,
      },
      claude = {
        cmd = function() vim.cmd("term claude") end,
        position = "left",
        size = 60,
      },
      lazygit = {
        cmd = function() vim.cmd("term lazygit") end,
        position = "float",
        size = { width = 0.95, height = 0.95 },
      },
      lazydocker = {
        cmd = function() vim.cmd("term lazydocker") end,
        position = "float",
        size = { width = 0.95, height = 0.95 },
      },
    },
  },
}
```

### コマンド設定

| キー       | 説明                              | デフォルト   |
| ---------- | --------------------------------- | ------------ |
| `cmd`      | 実行コマンド（文字列 or 関数）    | 必須         |
| `position` | ウィンドウ位置                    | `"bottom"`   |
| `size`     | サイズ（行/列数、floatは比率も可）| `20`         |

## 使い方

```vim
:Kocmd shell
:Kocmd lazygit
```
