local M = {}

local state = {
    count = "",
    ns = vim.api.nvim_create_namespace("JumpHighlight"),
}

local function on_number_typed(num_str)
    state.count = state.count .. num_str

    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)

    if state.count == "" then return end

    local cur_line = vim.fn.line(".")
    local win_top = vim.fn.line("w0")
    local win_bot = vim.fn.line("w$")
    local is_rel = vim.wo.relativenumber

    for i = win_top, win_bot do
        local num = is_rel and math.abs(i - cur_line) or i

        if vim.startswith(tostring(num), state.count) then
            vim.api.nvim_buf_set_extmark(buf, state.ns, i - 1, 0, {
                number_hl_group = "JumpHighlight",
                priority = 10000,
            })
        end
    end

    vim.cmd.redraw()
end

local function clear_highlights()
    if state.count == "" then return end

    state.count = ""
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)
        vim.cmd.redraw()
    end
end

local function chain_esc(existing)
    if existing and existing.rhs and existing.rhs ~= "" then
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes(existing.rhs, true, false, true), "n")
    elseif existing and existing.callback then
        existing.callback()
    else
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n")
    end
end

local function setup_esc_handler()
    local existing_n_esc = vim.fn.maparg("<Esc>", "n", false, true)
    local existing_v_esc = vim.fn.maparg("<Esc>", "v", false, true)

    vim.keymap.set("n", "<Esc>", function()
        clear_highlights()
        chain_esc(existing_n_esc)
    end, { noremap = true, silent = true, desc = "Clear jump highlights and Escape" })

    vim.keymap.set("v", "<Esc>", function()
        clear_highlights()
        chain_esc(existing_v_esc)
    end, { noremap = true, silent = true, desc = "Clear jump highlights and Escape" })
end

function M.setup(opts)
    opts = opts or {}

    vim.api.nvim_set_hl(0, "JumpHighlight", {
        bg = opts.bg,
        fg = opts.fg or "#EBCB8B",
        bold = true,
    })

    vim.on_key(function(key)
        local mode = vim.fn.mode()
        local is_visual = (mode == "v" or mode == "V" or mode == "\22")

        if (mode == "n" or is_visual) and key == "0" and state.count ~= "" then
            on_number_typed("0")
        end
    end, state.ns)

    for i = 1, 9 do
        vim.keymap.set({ "n", "v" }, tostring(i), function()
            on_number_typed(tostring(i))
            return tostring(i)
        end, { expr = true, noremap = true, silent = true })
    end

    if vim.v.vim_did_enter == 1 then
        setup_esc_handler()
    else
        vim.api.nvim_create_autocmd("VimEnter", {
            once = true,
            callback = setup_esc_handler,
        })
    end

    local group = vim.api.nvim_create_augroup("JumpHighlightInternal", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged", "BufLeave", "InsertEnter" }, {
        group = group,
        callback = clear_highlights,
    })
end

return M
