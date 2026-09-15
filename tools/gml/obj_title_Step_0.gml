if (!menu_open) {
    if (bb_hit_btn(btn_start) && mouse_check_button_pressed(mb_left)) {
        audio_stop_all();
        room_goto(rm_school);
    }
    if (bb_hit_btn(btn_menu) && mouse_check_button_pressed(mb_left)) {
        menu_open = true;
    }
    if ((keyboard_check_pressed(vk_enter) && !keyboard_check(vk_alt)) || keyboard_check_pressed(vk_space)) {
        audio_stop_all();
        room_goto(rm_school);
    }
} else {
    if ((bb_hit_btn(btn_back) && mouse_check_button_pressed(mb_left)) || keyboard_check_pressed(vk_escape)) {
        menu_open = false;
    }
}
