draw_clear(c_white);
if (!menu_open) {
    draw_sprite_stretched(spr_title, 0, 0, 0, bb_base_w(), bb_base_h());
    draw_set_font(global.fnt_big);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(bb_hit_btn(btn_start) ? c_red : c_black);
    draw_text((btn_start.x1 + btn_start.x2) * 0.5, (btn_start.y1 + btn_start.y2) * 0.5, "START");
    draw_set_color(bb_hit_btn(btn_menu) ? c_red : c_black);
    draw_text((btn_menu.x1 + btn_menu.x2) * 0.5, (btn_menu.y1 + btn_menu.y2) * 0.5, "MENU");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
} else {
    draw_set_font(global.fnt_big);
    draw_set_color(c_black);
    draw_set_halign(fa_center);
    draw_text(320, 40, "MENU");
    draw_set_font(global.fnt_ui);
    draw_text(320, 110, "WASD / Arrows  -  Walk");
    draw_text(320, 150, "Shift  -  Run");
    draw_text(320, 190, "Mouse  -  Look");
    draw_text(320, 230, "1 2 3 / Wheel  -  Item slot");
    draw_text(320, 270, "Right click / Q  -  Use item");
    draw_text(320, 310, "Esc  -  Pause");
    draw_text(320, 350, "F11  -  Fullscreen");
    draw_text(320, 400, "Collect 7 notebooks. Don't get caught.");
    draw_set_color(bb_hit_btn(btn_back) ? c_red : c_black);
    draw_set_font(global.fnt_big);
    draw_text((btn_back.x1 + btn_back.x2) * 0.5, (btn_back.y1 + btn_back.y2) * 0.5, "BACK");
    draw_set_halign(fa_left);
}
