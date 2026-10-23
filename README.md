<h4 align="center">
  <a href="#installation">Install</a>
  ·
  <a href="#configuration">Configure</a>
  ·
  <a href="#usage">Docs</a>
</h4>

<p align="center">
  A minimal Neovim REST client for <code>.http</code>/<code>.rest</code> files — inspired by
  <a href="https://github.com/Huachao/vscode-restclient">vscode-restclient</a>.
</p>

This is an MVP: using `curl` under the hood (via
`plenary.job`), file-level variables, and a response split. No external
runtime dependency beyond `curl` and `plenary.nvim`.

## ✨ Features

- 📝 Write requests in plain `.http`/`.rest` files, no special UI needed
- 🔀 Multiple requests per file, separated by `###`
- ⚡ Send the request under the cursor, or a visual selection, with `:RestClientRun`
- 🛑 Cancel an in-flight request with `:RestClientCancel`
- 🔖 File-level variables (`@name = value`) with `{{name}}` substitution in the URL, headers, and body
- 🔗 Named requests (`# @name id`) and request variables (`{{id.response.body.*}}` / `{{id.response.headers.*}}`) to chain requests
- 🧵 Multi-line query strings (`?key=value` / `&key=value` continuation lines)
- 📬 Response rendered in a reusable split: status, timing, size, headers, and a pretty-printed body (JSON auto-indented)
- 🎨 Basic syntax highlighting and filetype detection for `.http`/`.rest`
- 🩺 `:checkhealth restclient`
- 🧱 No external runtime dependency beyond `curl` and `plenary.nvim` — everything else is plain Lua

## ⚡️ Requirements

- Neovim >= 0.10
- [`curl`](https://curl.se/) on your `$PATH`
- [`plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)

## 🚀 Getting Started

Check [Installation](#installation) below to add it to your config, then
open a `.http` file and run `:RestClientRun`.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "daniel-eichinger-snkeos/nvim-restclient",
  dependencies = { "nvim-lua/plenary.nvim" },
  ft = { 'http', 'rest' },
  opts = {
    split = 'vertical',
  },
  keys = {
    { '<leader>rs', '<cmd>RestClientRun<cr>', desc = 'Send request' },
    { '<leader>rs', ':RestClientRun<cr>', mode = 'v', desc = 'Send request (selection)' },
    { '<leader>rc', '<cmd>RestClientCancel<cr>', desc = 'Cancel request' },
  },
}
```

## Usage

Write a request in a `.http` file:

```http
@host = httpbin.org

GET https://{{host}}/get?foo=bar
Accept: application/json

###

POST https://{{host}}/post
Content-Type: application/json

{
  "hello": "world"
}
```

Place your cursor anywhere inside a request block and run `:RestClientRun`.
The response opens in a split (vertical by default) with the status line,
timing, response size, headers, and body.

You can also visually select a range of lines and run `:RestClientRun` —
the selection is parsed as a single request, ignoring `###` boundaries.

Cancel a request that's taking too long with `:RestClientCancel`.

Bind your own keymaps, e.g.:

```lua
vim.keymap.set("n", "<leader>rs", "<cmd>RestClientRun<cr>", { desc = "Send HTTP request" })
vim.keymap.set("v", "<leader>rs", ":RestClientRun<cr>", { desc = "Send HTTP request (selection)" })
vim.keymap.set("n", "<leader>rc", "<cmd>RestClientCancel<cr>", { desc = "Cancel HTTP request" })
```

### Request syntax

```
METHOD URL [HTTP/1.1]
Header-Name: value
...
<blank line>
body...
```

- `METHOD` is optional and defaults to `GET`.
- Query strings can be spread across lines right after the request line:

  ```http
  GET https://example.com/comments
      ?page=2
      &pageSize=10
  ```

- Lines starting with `#` or `//` before the request line / among headers
  are treated as comments.
- `@name = value` defines a file-level variable, usable anywhere in the
  file via `{{name}}` (including in other variable definitions).

### Request variables

Name a request with a `# @name <id>` (or `// @name <id>`) comment line placed
before its request line, then reference its response elsewhere in the file
via `{{id.response.body.*}}` or `{{id.response.headers.*}}`:

```http
# @name registerClient
POST {{baseUrl}}/oauth2/register
Content-Type: application/json

{ "client_name": "Test Client" }

@clientId = {{registerClient.response.body.client_id}}

###

GET {{baseUrl}}/oauth2/register/{{clientId}}
Accept: application/json
```

## Configuration

```lua
require("restclient").setup({
  split = "vertical", -- or "horizontal"
  timeout_ms = 30000,
  curl_path = "curl",
  insecure = true, -- pass `-k` to curl to skip TLS certificate verification
})
```

