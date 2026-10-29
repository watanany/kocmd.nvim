# kocmd.nvim

コマンド出力パネルのトグル管理プラグイン。

## 機能

- コマンドごとにスプリット/フローティングウィンドウをトグル表示
- タブごとに状態を保持(バッファの内容を保ったまま開閉できる)
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
        cmd = vim.o.shell,
        position = "bottom",
        size = 20,
      },
      claude = {
        cmd = "claude",
        position = "left",
        size = 60,
      },
      lazygit = {
        cmd = "lazygit",
        position = "float",
        size = { width = 0.95, height = 0.95 },
      },
      lazydocker = {
        cmd = "lazydocker",
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
| `cmd`      | シェルコマンド(文字列・リスト、またはそれを返す関数。関数は起動のたびに呼ぶ) | 必須 |
| `position` | ウィンドウ位置                    | `"bottom"`   |
| `size`     | サイズ(行/列数、float は比率も可)| `20`         |
| `session`  | セッションに保存し、読み込み後も kocmd のウィンドウとして扱う(float は対象外) | `false` |
| `restore_cmd` | `fun(buf): string?`。セッション保存時に呼ばれ、返したコマンドを読み込み時に実行する。nil を返すと元のコマンドのまま。`session = true` のときだけ効く | なし |

## セッション

`session = true` のコマンドは、`:mksession` や neovim-session-manager などでセッションを保存すると一緒に保存され、読み込み後も同じタブの kocmd として扱われる。

- 保存時(`SessionWritePost`)に、タブ番号とバッファ名の対応表をセッションファイルに `g:KocmdSession` として書き込む
- 読み込み時(`SessionLoadPost`)に、対応表のバッファを kocmd のウィンドウとして扱う。表示していなかったものは、次に toggle したときに起動する
- 起動時のセッション読み込みに間に合うよう、lazy.nvim では `lazy = false` にする
- `restore_cmd` は、一度も開いていない(読み込まれていない)バッファでは呼ばない。そのバッファは前回のコマンドのまま保存する

```lua
claude = {
  cmd = "claude",
  position = "left",
  session = true,
  -- 元の会話を再開させる例
  restore_cmd = function(buf)
    local id = find_session_id(buf)
    return id and ("claude --resume " .. id) or nil
  end,
},
```

## kocmd のバッファの見分け方

kocmd が作った terminal のバッファには、次の 2 つが付いている。ほかのプラグインから見分けるときに使える。

- `vim.b[buf].kocmd_name`: コマンドの名前(`commands` のキー)
- `filetype`: `kocmd`

## 使い方

```vim
:Kocmd shell
:Kocmd lazygit
```
