/*
 * vala-panel-appmenu
 * Copyright (C) 2015 Konstantin Pugin <ria.freelander@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using Gtk;
using DBus;

namespace Key
{
    public const string COMPACT_MODE = "compact-mode";
    public const string BOLD_APPLICATION_NAME = "bold-application-name";
}

namespace Appmenu {
    public class Constants {
        public const string COMPACT_MODE = "compact-mode";
        public const string BOLD_APPLICATION_NAME = "bold-application-name";
    }

    public class MenuWidget : Gtk.Bin
    {
        public bool compact_mode;
        public bool bold_application_name;
        private Gtk.Adjustment? scroll_adj = null;
        private Gtk.ScrolledWindow? scroller = null;
        private Gtk.CssProvider provider;
        private GLib.MenuModel? appmenu = null;
        private GLib.MenuModel? menubar = null;
        private Backend backend = new BackendImpl();
        private Gtk.MenuBar mwidget = new Gtk.MenuBar();
        private ulong backend_connector = 0;
        private ulong compact_connector = 0;

        private DBusMenuRegistrarProxy menu_registrar_proxy;

        construct
        {
            provider = new Gtk.CssProvider();
            provider.load_from_resource("/org/vala-panel/appmenu/appmenu.css");
            unowned Gtk.StyleContext context = this.get_style_context();
            context.add_class("-vala-panel-appmenu-core");
            unowned Gtk.StyleContext mcontext = mwidget.get_style_context();
            Signal.connect(this, "notify", (GLib.Callback)restock, null);
            backend_connector = backend.active_model_changed.connect(() =>
            {
                Timeout.add(50, () =>
                {
                    backend.set_active_window_menu(this);
                    return Source.REMOVE;
                });
            });
            mcontext.add_class("-vala-panel-appmenu-private");
            Gtk.StyleContext.add_provider_for_screen(this.get_screen(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            scroll_adj = new Gtk.Adjustment(0, 0, 0, 20, 20, 0);
            scroller = new Gtk.ScrolledWindow(scroll_adj, null);
            scroller.set_hexpand(true);
            scroller.set_policy(Gtk.PolicyType.EXTERNAL, Gtk.PolicyType.NEVER);
            scroller.set_shadow_type(Gtk.ShadowType.NONE);
            scroller.scroll_event.connect(on_scroll_event);
            scroller.set_min_content_width(16);
            scroller.set_min_content_height(16);
            scroller.set_propagate_natural_height(true);
            scroller.set_propagate_natural_width(true);
            this.add(scroller);
            scroller.add(mwidget);
            mwidget.show();
            scroller.show();
            this.show();

            menu_registrar_proxy = new DBusMenuRegistrarProxy();
        }

        public MenuWidget()
        {
        }

        private void restock()
        {
            var menu = new GLib.Menu();
            if (this.appmenu != null)
                menu.append_section(null, this.appmenu);
            if (this.menubar != null)
                menu.append_section(null, this.menubar);

            int items = -1;
            if (this.menubar != null)
                items = this.menubar.get_n_items();

            if (this.compact_mode && items == 0)
            {
                compact_connector = this.menubar.items_changed.connect((a, b, c) =>
                {
                    restock();
                });
            }
            if (this.compact_mode && items > 0)
            {
                if (compact_connector > 0)
                {
                    this.menubar.disconnect(compact_connector);
                    compact_connector = 0;
                }
                var compact = new GLib.Menu();
                string? name = null;
                if (this.appmenu != null)
                    this.appmenu.get_item_attribute(0, "label", "s", &name);
                else
                    name = GLib.dgettext(Config.GETTEXT_PACKAGE, "Compact Menu");
                compact.append_submenu(name, menu);
                mwidget.bind_model(compact, null, true);
            }
            else
                mwidget.bind_model(menu, null, true);

            unowned Gtk.StyleContext mcontext = mwidget.get_style_context();
            if (bold_application_name)
                mcontext.add_class("-vala-panel-appmenu-bold");
            else
                mcontext.remove_class("-vala-panel-appmenu-bold");
        }

        public void set_appmenu(GLib.MenuModel? appmenu_model)
        {
            this.appmenu = appmenu_model;
            this.restock();
        }

        public void set_menubar(GLib.MenuModel? menubar_model)
        {
            this.menubar = menubar_model;
            this.restock();
        }

        protected bool on_scroll_event(Gtk.Widget w, Gdk.EventScroll event)
        {
            var val = scroll_adj.get_value();
            var incr = scroll_adj.get_step_increment();
            if (event.direction == Gdk.ScrollDirection.UP)
            {
                scroll_adj.set_value(val - incr);
                return true;
            }
            if (event.direction == Gdk.ScrollDirection.DOWN)
            {
                scroll_adj.set_value(val + incr);
                return true;
            }
            if (event.direction == Gdk.ScrollDirection.LEFT)
            {
                scroll_adj.set_value(val - incr);
                return true;
            }
            if (event.direction == Gdk.ScrollDirection.RIGHT)
            {
                scroll_adj.set_value(val + incr);
                return true;
            }
            if (event.direction == Gdk.ScrollDirection.SMOOTH)
            {
                scroll_adj.set_value(val + incr * (event.delta_y + event.delta_x));
                return true;
            }
            return false;
        }

        protected override void map()
        {
            base.map();
            unowned Gtk.Settings gtksettings = this.get_settings();
            gtksettings.gtk_shell_shows_app_menu = false;
            gtksettings.gtk_shell_shows_menubar = false;
        }

        public void get_menu_for_window(uint window_id, out string name, out ObjectPath path)
        {
            path = new ObjectPath("/");
            name = string.Empty;

            if (!menu_registrar_proxy.have_registrar)
                return;

            menu_registrar_proxy.get_menu_for_window(window_id, out name, out path);
        }
    }
}

public class DBusMenuRegistrarProxy : Object
{
    public bool have_registrar { get; private set; }
    private InnerRegistrar inner_registrar;
    private OuterRegistrar outer_registrar;
    private bool is_inner_registrar;
    private uint owned_name;
    private uint watched_name;

    public DBusMenuRegistrarProxy()
    {
    }

    public signal void window_registered(uint window_id, string service, ObjectPath path);
    public signal void window_unregistered(uint window_id);

    private void on_bus_aquired(DBusConnection conn)
    {
        try
        {
            inner_registrar = new InnerRegistrar();
            outer_registrar = null;
            conn.register_object(REG_OBJECT, inner_registrar);
            inner_registrar.window_registered.connect((w, s, p) => { this.window_registered(w, s, p); });
            inner_registrar.window_unregistered.connect((w) => { this.window_unregistered(w); });
        }
        catch (IOError e)
        {
            stderr.printf("Could not register service. Waiting for external registrar\n");
        }
    }

    private void create_inner_registrar()
    {
        owned_name = Bus.own_name(BusType.SESSION, REG_IFACE, BusNameOwnerFlags.NONE,
            on_bus_aquired,
            () =>
            {
                have_registrar = true;
                is_inner_registrar = true;
            },
            () =>
            {
                is_inner_registrar = false;
                create_outer_registrar();
            });
    }

    private void create_outer_registrar()
    {
        try
        {
            outer_registrar = Bus.get_proxy_sync(BusType.SESSION, REG_IFACE, REG_OBJECT);
            watched_name = Bus.watch_name(BusType.SESSION, REG_IFACE, GLib.BusNameWatcherFlags.NONE,
                () =>
                {
                    inner_registrar = null;
                    is_inner_registrar = false;
                    have_registrar = true;
                },
                () =>
                {
                    have_registrar = false;
                    Bus.unwatch_name(watched_name);
                    is_inner_registrar = true;
                    create_inner_registrar();
                    create_outer_registrar();
                });
            outer_registrar.window_registered.connect((w, s, p) => { this.window_registered(w, s, p); });
        }
        catch (Exception e)
        {
            stderr.printf("Error creating outer registrar: %s\n", e.Message);
        }
    }

    public void get_menu_for_window(uint window, out string name, out ObjectPath path)
    {
        path = new ObjectPath("/");
        if (!have_registrar)
            return;

        if (is_inner_registrar)
            inner_registrar.get_menu_for_window(window, out name, out path);
        else
            try
            {
                outer_registrar.get_menu_for_window(window, out name, out path);
            }
            catch (Error e)
            {
                stderr.printf("%s\n", e.message);
            }
    }

    ~DBusMenuRegistrarProxy()
    {
        if (is_inner_registrar)
            Bus.unown_name(owned_name);
        else
            Bus.unwatch_name(watched_name);
        Bus.unwatch_name(watched_name);
    }
}
