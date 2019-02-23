/*
* Copyright (c) 2017 Lains
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/
using Gtk;
using Granite;
using Granite.Services;

namespace Quilter {
    public class MainWindow : Gtk.Window {
        public Widgets.StatusBar statusbar;
        public Widgets.SideBar sidebar;
        public Widgets.SearchBar searchbar;
        public Widgets.Headerbar toolbar;
        public Gtk.MenuButton set_font_menu;
        public Widgets.EditView edit_view_content;
        public Widgets.Preview preview_view_content;
        public Gtk.Stack stack;
        public Gtk.ScrolledWindow edit_view;
        public Gtk.ScrolledWindow preview_view;
        public Gtk.Grid grid;
        public Gtk.Grid main_pane;
        public SimpleActionGroup actions { get; construct; }
        public const string ACTION_PREFIX = "win.";
        public const string ACTION_CHEATSHEET = "action_cheatsheet";
        public const string ACTION_PREFS = "action_preferences";
        public const string ACTION_EXPORT_PDF = "action_export_pdf";
        public const string ACTION_EXPORT_HTML = "action_export_html";
        public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

        private const GLib.ActionEntry[] action_entries = {
            { ACTION_CHEATSHEET, action_cheatsheet },
            { ACTION_PREFS, action_preferences },
            { ACTION_EXPORT_PDF, action_export_pdf },
            { ACTION_EXPORT_HTML, action_export_html }
        };

        public bool is_fullscreen {
            get {
                var settings = AppSettings.get_default ();
                return settings.fullscreen;
            }
            set {
                var settings = AppSettings.get_default ();
                settings.fullscreen = value;

                if (settings.fullscreen) {
                    fullscreen ();
                    settings.statusbar = false;
                    var buffer_context = edit_view_content.get_style_context ();
                    buffer_context.add_class ("full-text");
                    buffer_context.remove_class ("small-text");
                } else {
                    unfullscreen ();
                    settings.statusbar = true;
                    var buffer_context = edit_view_content.get_style_context ();
                    buffer_context.add_class ("small-text");
                    buffer_context.remove_class ("full-text");
                }

                // Update margins
                if (this != null)
                    dynamic_margins ();
            }
        }

        public MainWindow (Gtk.Application application) {
            Object (application: application,
                    resizable: true,
                    title: _("Quilter"),
                    height_request: 600,
                    width_request: 700);

            weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
            default_theme.add_resource_path ("/com/github/lainsce/quilter");

            var settings = AppSettings.get_default ();

            show_statusbar ();
            show_sidebar ();
            update_count ();
            show_font_button (false);

            if (!settings.focus_mode) {
                set_font_menu.image = new Gtk.Image.from_icon_name ("set-font", Gtk.IconSize.LARGE_TOOLBAR);
            } else {
                set_font_menu.image = new Gtk.Image.from_icon_name ("font-select-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            }

            settings.changed.connect (() => {
                show_statusbar ();
                show_sidebar ();
                show_searchbar ();
                update_count ();

                if (!settings.focus_mode) {
                    set_font_menu.image = new Gtk.Image.from_icon_name ("set-font", Gtk.IconSize.LARGE_TOOLBAR);
                } else {
                    set_font_menu.image = new Gtk.Image.from_icon_name ("font-select-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
                }
            });

            if (edit_view_content != null) {
                edit_view_content.buffer.changed.connect (() => {
                    render_func ();
                    update_count ();
                });
            }

            key_press_event.connect ((e) => {
                uint keycode = e.hardware_keycode;
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.q, keycode)) {
                        this.destroy ();
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.s, keycode)) {
                        try {
                            File file = File.new_for_path (settings.current_file);
                            Services.FileManager.save (file);
                        } catch (Error e) {
                            warning ("Unexpected error during open: " + e.message);
                        }
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.o, keycode)) {
                        try {
                            Services.FileManager.open (this);
                        } catch (Error e) {
                            warning ("Unexpected error during open: " + e.message);
                        }
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.f, keycode)) {
                        if (settings.searchbar == false) {
                            settings.searchbar = true;
                            searchbar.search_entry.grab_focus_without_selecting();
                        } else {
                            settings.searchbar = false;
                        }
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.h, keycode)) {
                        var cheatsheet_dialog = new Widgets.Cheatsheet (this);
                        cheatsheet_dialog.show_all ();
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.z, keycode)) {
                        edit_view_content.do_undo ();
                    }
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK + Gdk.ModifierType.SHIFT_MASK) != 0) {
                    if (match_keycode (Gdk.Key.z, keycode)) {
                        edit_view_content.do_redo ();
                    }
                }
                if (match_keycode (Gdk.Key.F11, keycode)) {
                    is_fullscreen = !is_fullscreen;
                }
                if (match_keycode (Gdk.Key.F1, keycode)) {
                    debug ("Press to change view...");
                    if (this.stack.get_visible_child_name () == "preview_view") {
                        this.stack.set_visible_child (this.edit_view);
                    } else if (this.stack.get_visible_child_name () == "edit_view") {
                        this.stack.set_visible_child (this.preview_view);
                    }
                    return true;
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.@1, keycode)) {
                        debug ("Press to change view...");
                        if (this.stack.get_visible_child_name () == "preview_view") {
                            this.stack.set_visible_child (this.edit_view);
                        } else if (this.stack.get_visible_child_name () == "edit_view") {
                            this.stack.set_visible_child (this.preview_view);
                        }
                        return true;
                    }
                }
                if (match_keycode (Gdk.Key.F2, keycode)) {
                    debug ("Press to change view...");
                    if (settings.sidebar) {
                        settings.sidebar = false;
                    } else {
                        settings.sidebar = true;
                    }
                    return true;
                }
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.@2, keycode)) {
                        debug ("Press to change view...");
                        if (settings.sidebar) {
                            settings.sidebar = false;
                        } else {
                            settings.sidebar = true;
                        }
                        return true;
                    }
                }
                return false;
            });
        }

        construct {
            var settings = AppSettings.get_default ();
            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/com/github/lainsce/quilter/app-main-stylesheet.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            var provider2 = new Gtk.CssProvider ();
            provider2.load_from_resource ("/com/github/lainsce/quilter/app-font-stylesheet.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider2, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            toolbar = new Widgets.Headerbar (this);
            toolbar.title = this.title;
            toolbar.has_subtitle = false;
            this.set_titlebar (toolbar);

            var set_font_sans = new Gtk.RadioButton.with_label_from_widget (null, _("Use Sans-serif"));
	        set_font_sans.toggled.connect (() => {
	            settings.preview_font = "sans";
	        });

	        var set_font_serif = new Gtk.RadioButton.with_label_from_widget (set_font_sans, _("Use Serif"));
	        set_font_serif.toggled.connect (() => {
	            settings.preview_font = "serif";
	        });
	        set_font_serif.set_active (true);

	        var set_font_mono = new Gtk.RadioButton.with_label_from_widget (set_font_sans, _("Use Monospace"));
	        set_font_mono.toggled.connect (() => {
	            settings.preview_font = "mono";
	        });

            var set_font_menu_grid = new Gtk.Grid ();
            set_font_menu_grid.margin = 12;
            set_font_menu_grid.row_spacing = 12;
            set_font_menu_grid.column_spacing = 12;
            set_font_menu_grid.orientation = Gtk.Orientation.VERTICAL;
            set_font_menu_grid.add (set_font_sans);
            set_font_menu_grid.add (set_font_serif);
            set_font_menu_grid.add (set_font_mono);
            set_font_menu_grid.show_all ();

            var set_font_menu_pop = new Gtk.Popover (null);
            set_font_menu_pop.add (set_font_menu_grid);

            set_font_menu = new Gtk.MenuButton ();
            set_font_menu.tooltip_text = _("Set Preview Font");
            set_font_menu.popover = set_font_menu_pop;

            edit_view = new Gtk.ScrolledWindow (null, null);
            edit_view_content = new Widgets.EditView ();
            edit_view_content.monospace = true;
            edit_view.add (edit_view_content);

            preview_view = new Gtk.ScrolledWindow (null, null);
            preview_view_content = new Widgets.Preview ();
            preview_view.add (preview_view_content);

            stack = new Gtk.Stack ();
            stack.hexpand = true;
            stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
            stack.add_titled (edit_view, "edit_view", _("Edit"));
            stack.add_titled (preview_view, "preview_view", _("Preview"));

            stack.set_visible_child (this.edit_view);

            var view_mode = new Gtk.StackSwitcher ();
            view_mode.stack = stack;
            view_mode.valign = Gtk.Align.CENTER;
            view_mode.homogeneous = true;

            ((Gtk.RadioButton)(view_mode.get_children().first().data)).set_active (true);
            ((Gtk.RadioButton)(view_mode.get_children().first().data)).toggled.connect(() => {
                show_font_button (false);
            });
            ((Gtk.RadioButton)(view_mode.get_children().last().data)).toggled.connect(() => {
                show_font_button (true);
            });

            toolbar.pack_end (view_mode);
            toolbar.pack_end (set_font_menu);

            actions = new SimpleActionGroup ();
            actions.add_action_entries (action_entries, this);
            insert_action_group ("win", actions);

            statusbar = new Widgets.StatusBar ();
            sidebar = new Widgets.SideBar (this);
            searchbar = new Widgets.SearchBar (this);

            grid = new Gtk.Grid ();
            grid.set_column_homogeneous (false);
            grid.set_row_homogeneous (false);
            grid.orientation = Gtk.Orientation.VERTICAL;
            grid.attach (searchbar, 0, 0, 2, 1);
            grid.attach (sidebar, 0, 1, 1, 1);
            grid.attach (stack, 1, 1, 1, 1);
            grid.attach (statusbar, 0, 2, 2, 1);
            grid.show_all ();
            this.add (grid);

            int x = settings.window_x;
            int y = settings.window_y;
            int h = settings.window_height;
            int w = settings.window_width;

            bool v = settings.shown_view;
            if (v) {
                this.stack.set_visible_child (this.preview_view);
            }

            if (x != -1 && y != -1) {
                this.move (x, y);
            }
            if (w != 0 && h != 0) {
                this.resize (w, h);
            }

            if (settings.current_file == "") {
                var tmp_file = File.new_for_path (Services.FileManager.cache);
                settings.current_file = tmp_file.get_path ();
                toolbar.set_subtitle ("No Documents Open");
            }

            // Register for redrawing of window for handling margins and other
            // redrawing
            configure_event.connect ((event) => {
                if (this != null)
                    dynamic_margins ();
            });

            // Attempt to set taskbar icon
            try {
                this.icon = IconTheme.get_default ().load_icon ("com.github.lainsce.quilter", Gtk.IconSize.DIALOG, 0);
            } catch (Error e) {
            }

            this.window_position = Gtk.WindowPosition.CENTER;
            this.show_all ();
        }

#if VALA_0_42
        protected bool match_keycode (uint keyval, uint code) {
#else
        protected bool match_keycode (int keyval, uint code) {
#endif
            Gdk.KeymapKey [] keys;
            Gdk.Keymap keymap = Gdk.Keymap.get_for_display (Gdk.Display.get_default ());
            if (keymap.get_entries_for_keyval (keyval, out keys)) {
                foreach (var key in keys) {
                    if (code == key.keycode)
                        return true;
                    }
                }

            return false;
        }

        public override bool delete_event (Gdk.EventAny event) {
            int x, y, w, h;
            get_position (out x, out y);
            get_size (out w, out h);
            bool v = set_font_menu.get_visible ();

            var settings = AppSettings.get_default ();
            settings.window_x = x;
            settings.window_y = y;
            settings.window_width = w;
            settings.window_height = h;
            settings.shown_view = v;
            string file_path = settings.current_file;

            if (settings.current_file != "") {
                debug ("Saving working file...");
                try {
                    File file = File.new_for_path(file_path);
                    Services.FileManager.save (file);
                } catch (Error err) {
                    print ("Error writing file: " + err.message);
                }
            } else if (file_path == "No Open Files") {
                debug ("Saving cache...");
                Services.FileManager.save_tmp_file ();
            }
            return false;
        }

        public void dynamic_margins () {
            var settings = AppSettings.get_default ();
            int w, h, m, p;
            this.get_size (out w, out h);

            // If Quilter is Full Screen, add additional padding
            p = (is_fullscreen) ? 5 : 0;

            var margins = settings.margins;
            switch (margins) {
                case Constants.NARROW_MARGIN:
                    m = (int)(w * ((Constants.NARROW_MARGIN + p) / 100.0));
                    break;
                case Constants.WIDE_MARGIN:
                    m = (int)(w * ((Constants.WIDE_MARGIN + p) / 100.0));
                    break;
                default:
                case Constants.MEDIUM_MARGIN:
                    m = (int)(w * ((Constants.MEDIUM_MARGIN + p) / 100.0));
                    break;
            }

            if (edit_view_content != null) {
                // Update margins
                edit_view_content.left_margin = m;
                edit_view_content.right_margin = m;

                // Update margins for typewriter scrolling
                if (settings.typewriter_scrolling && settings.focus_mode) {
                    int titlebar_h = this.get_titlebar().get_allocated_height();
                    edit_view_content.bottom_margin = (int)(h * (1 - Constants.TYPEWRITER_POSITION)) - titlebar_h;
                    edit_view_content.top_margin = (int)(h * Constants.TYPEWRITER_POSITION) - titlebar_h;
                } else {
                    edit_view_content.bottom_margin = 40;
                    edit_view_content.top_margin = 40;
                }
            }
        }

        private void update_count () {
            var settings = AppSettings.get_default ();
            if (settings.track_type == "words") {
                statusbar.update_wordcount ();
                settings.track_type = "words";
            } else if (settings.track_type == "lines") {
                statusbar.update_linecount ();
                settings.track_type = "lines";
            } else if (settings.track_type == "chars") {
                statusbar.update_charcount ();
                settings.track_type = "chars";
            }
        }

        private void action_preferences () {
            var dialog = new Widgets.Preferences (this);
            dialog.set_modal (true);
            dialog.show_all ();
        }

        private void action_cheatsheet () {
            var dialog = new Widgets.Cheatsheet (this);
            dialog.set_modal (true);
            dialog.show_all ();
        }

        private void action_export_pdf () {
            Services.ExportUtils.export_pdf ();
        }

        private void action_export_html () {
            Services.ExportUtils.export_html ();
        }

        private void render_func () {
            if (edit_view_content.buffer.get_modified () == true) {
                preview_view_content.update_html_view ();
                edit_view_content.buffer.set_modified (false);
            }
        }

        public void show_sidebar () {
            var settings = AppSettings.get_default ();
            sidebar.show_this = settings.sidebar;
            sidebar.reveal_child = settings.sidebar;
        }

        public void show_statusbar () {
            var settings = AppSettings.get_default ();
            statusbar.reveal_child = settings.statusbar;
        }

        public void show_searchbar () {
            var settings = AppSettings.get_default ();
            searchbar.reveal_child = settings.searchbar;
        }

        public void show_font_button (bool v) {
            set_font_menu.visible = v;
        }
    }
}
