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
 //using Key;
 using Appmenu;
 
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
 