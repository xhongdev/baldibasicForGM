bb_ui_begin();
draw_clear(c_white);
draw_set_font(global.fnt_big);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_color(c_black);
if (menu_page=="title") draw_sprite_stretched(spr_title,0,0,0,640,480);
else {
    var _heading="MENU";
    if (menu_page=="modes") _heading="SELECT MODE";
    if (menu_page=="controls") _heading="HOW TO PLAY";
    if (menu_page=="options") _heading="OPTIONS";
    draw_text(320,45,_heading);
    draw_set_font(global.fnt_ui);
    if (menu_page=="modes") {
        draw_text(320,155,"Collect all 7 notebooks and escape the school.");
        draw_text(320,285,"Collect as many notebooks as you can!");
        draw_text(320,320,"High Score: "+string(global.high_books)+" Notebooks");
    }
    if (menu_page=="controls") {
        var _lines=["WASD / Arrows - Walk     Shift - Run","Mouse - Look     Space - Look behind",
            "Left click - Doors, notebooks and items","1 2 3 / Wheel - Item slot",
            "Right click / Q - Use item","Space / E / Left click - Jump rope",
            "Esc - Pause     F11 - Fullscreen"];
        for (var _i=0;_i<array_length(_lines);_i++) draw_text(320,110+_i*40,_lines[_i]);
    }
    if (menu_page=="options") {
        draw_text(320,115,"Mouse sensitivity");
        draw_text(320,155,string_format(global.mouse_sensitivity,1,1));
        draw_text(320,220,"Volume");
        draw_text(320,260,string(round(global.master_volume*100))+"%");
    }
}
draw_set_font(global.fnt_big);
for (var _i=0;_i<array_length(menu_buttons);_i++) {
    var _b=menu_buttons[_i];
    draw_set_color(_i==menu_selection?c_red:c_black);
    draw_text((_b.x1+_b.x2)*.5,(_b.y1+_b.y2)*.5,_b.label);
}
draw_set_halign(fa_left);draw_set_valign(fa_top);draw_set_color(c_white);
if (global.bb_selftest) surface_save(application_surface,"bb_menu_"+menu_page+".png");
