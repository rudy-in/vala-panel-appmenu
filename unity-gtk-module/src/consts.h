/*
 * appmenu-gtk-module
 * Copyright 2012 Canonical Ltd.
 * Copyright (C) 2015-2017 Konstantin Pugin <ria.freelander@gmail.com>
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
 *
 * Authors: Ryan Lortie <desrt@desrt.ca>
 *          William Hua <william.hua@canonical.com>
 *          Konstantin Pugin <ria.freelander@gmail.com>
 */

#define UNITY_GTK_MODULE_SCHEMA "org.valapanel.appmenu-gtk-module"
#define BLACKLIST_KEY "blacklist"
#define WHITELIST_KEY "whitelist"
#define SHELL_SHOWS_MENUBAR_KEY "gtk2-shell-shows-menubar"

#define _GTK_UNIQUE_BUS_NAME "_GTK_UNIQUE_BUS_NAME"
#define _UNITY_OBJECT_PATH "_UNITY_OBJECT_PATH"
#define _GTK_MENUBAR_OBJECT_PATH "_GTK_MENUBAR_OBJECT_PATH"
#define OBJECT_PATH "/org/valapanel/appmenu/gtk/window"