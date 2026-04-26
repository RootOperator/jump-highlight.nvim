local M = {}

local state = {
    count = "",
    ns = vim.api.nvim_create_namespace("JumpHighlight"),
}

local function clear_highlights()
    if state.count == "" then return end
    state.count = ""
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)
        vim.cmd.redraw()
    end
end

local function on_number_typed(char)
    state.count = state.count .. char
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)

    local count = tonumber(state.count)
    if not count then return end

    local cur = vim.fn.line(".")
    local top, bot = vim.fn.line("w0"), vim.fn.line("w$")
    local is_rel = vim.wo.relativenumber
    local opts = { number_hl_group = "JumpHighlight", priority = 10000 }

    local function mark(line)
        local clamped = math.max(top, math.min(bot, line))
        vim.api.nvim_buf_set_extmark(buf, state.ns, clamped - 1, 0, opts)
    end

    for i = top, bot do
        local num = is_rel and math.abs(i - cur) or i
        if vim.startswith(tostring(num), state.count) then mark(i) end
    end

    if is_rel then
        mark(cur - count)
        mark(cur + count)
    else
        mark(count)
    end

    vim.cmd.redraw()
end

function M.setup(opts)
    opts = opts or {}
    vim.api.nvim_set_hl(0, "JumpHighlight", {
        bg = opts.bg,
        fg = opts.fg or "#EBCB8B",
        bold = true,
    })

    vim.on_key(function(key)
        if vim.fn.mode():match("^[isS]") then return end

        local byte = string.byte(key)
        if not byte then return end

        if (byte >= 49 and byte <= 57) or (byte == 48 and state.count ~= "") then
            on_number_typed(string.char(byte))
        end
    end, state.ns)

    local function setup_esc()
        local orig = vim.fn.maparg("<Esc>", "n", false, true)
        vim.keymap.set("n", "<Esc>", function()
            clear_highlights()
            if orig and orig.callback then
                orig.callback()
            else
                local keys = (orig and orig.rhs and orig.rhs ~= "") and orig.rhs or "<Esc>"
                vim.fn.feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n")
            end
        end, { noremap = true, silent = true })
    end

    if vim.v.vim_did_enter == 1 then
        setup_esc()
    else
        vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = setup_esc })
    end

    vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged", "BufLeave", "InsertEnter" }, {
        callback = clear_highlights,
    })
end

return M
