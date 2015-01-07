/***
Copyright (C) 2014-2015 Marvin Beckers
This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License version 3, as published
by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranties of
MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see http://www.gnu.org/licenses/.

Authored by: Marvin Beckers <beckersmarvin@gmail.com>
Authored by: Switchboard Locale Plug Developers
***/

namespace SwitchboardPlugUserAccounts {
	private static string[]? installed_languages = null;

	public static string[]? get_installed_languages () {
		if (installed_languages != null)
			return installed_languages;

		string output;
		int status;

		try {
			Process.spawn_sync (null, 
				{"/usr/share/language-tools/language-options" , null}, 
				Environ.get (),
				SpawnFlags.SEARCH_PATH,
				null,
				out output,
				null,
				out status);

				installed_languages = output.split("\n");
				return installed_languages;
		} catch (Error e) {
			return null;
		}
	}

	private static Polkit.Permission? permission = null;

	public static Polkit.Permission? get_permission () {
		if (permission != null)
			return permission;
		try {
			permission = new Polkit.Permission.sync ("org.pantheon.user-accounts.administration", Polkit.UnixProcess.new (Posix.getpid ()));
			return permission;
		} catch (Error e) {
			critical (e.message);
			return null;
		}
	}

	private static Act.UserManager? usermanager = null;

	public static unowned Act.UserManager? get_usermanager () {
		if (usermanager != null && usermanager.is_loaded)
			return usermanager;

		usermanager = Act.UserManager.get_default ();
		return usermanager;
	}

	private static Act.User? current_user = null;

	public static unowned Act.User? get_current_user () {
		if (current_user != null)
			return current_user;

		current_user = get_usermanager ().get_user (GLib.Environment.get_user_name ());
		return current_user;
	}

	private static List<Act.User>? removal_list = null;

	public static unowned List<Act.User> get_removal_list () {
		if (removal_list != null)
			return removal_list;

		removal_list = new List<Act.User> ();
		return removal_list;
	}

	public static void clear_removal_list () {
		removal_list = null;
	}

	public static void mark_removal (Act.User user) {
		if (removal_list == null)
			get_removal_list ();

		removal_list.append (user);
	}

	public static void undo_removal () {
		if (removal_list != null && removal_list.last () != null) {
			removal_list.remove (removal_list.last ().data);
		}
	}

	public static bool check_removal (Act.User user) {
		if (removal_list != null && removal_list.last () != null) {
			unowned List<Act.User>? find = removal_list.find (user);
			if (find != null)
				return true;
			else
				return false;
		}
		return false;
	}

	public static bool is_last_admin (Act.User? user) {
		if (user != null) {
			foreach (unowned Act.User temp_user in get_usermanager ().list_users ()) {
				if (temp_user != user && temp_user.get_account_type () == Act.UserAccountType.ADMINISTRATOR)
					return false;
			}
			return true;
		}
		return false;
	}

	public static void create_new_user (string _fullname, string _username, Act.UserAccountType _usertype,
															Act.UserPasswordMode _mode, string? _pw = null) {
		if (get_permission ().allowed) {
			try {
				Act.User created_user = get_usermanager ().create_user (_username, _fullname, _usertype);
				get_usermanager ().user_added.connect ((user) => {
					if (user == created_user) {
						created_user.set_locked (false);
							if (_mode == Act.UserPasswordMode.REGULAR && _pw != null)
								created_user.set_password (_pw, "");
							else if (_mode == Act.UserPasswordMode.NONE)
								created_user.set_password_mode (Act.UserPasswordMode.NONE);
							else if (_mode == Act.UserPasswordMode.SET_AT_LOGIN)
								created_user.set_password_mode (Act.UserPasswordMode.SET_AT_LOGIN);
					}
				});
			} catch (Error e) {
				critical ("Creation of user '%s' failed".printf (_username));
			}
		}
	}

	private static Passwd.Handler passwd_handler;

	public static unowned Passwd.Handler? get_passwd_handler (bool _force_new = false) {
		if (passwd_handler != null && !_force_new)
			return passwd_handler;

		passwd_handler = new Passwd.Handler ();
		return passwd_handler;
	}

	private static bool? guest_session_state;

	public static bool? get_guest_session_state () {
		if (guest_session_state != null)
			return guest_session_state;

		string output;
		int status;

		try {
			Process.spawn_sync (null, 
				{"/usr/lib/x86_64-linux-gnu/switchboard/system/pantheon-useraccounts/guest-session-toggle", "--show"}, 
				Environ.get (),
				SpawnFlags.SEARCH_PATH,
				null,
				out output,
				null,
				out status);

			if (output == "off\n")
				guest_session_state = false;
			else
				guest_session_state = true;

			return guest_session_state;
		} catch (Error e) {
			warning (e.message);
			return null;
		}
	}

	public static void set_guest_session_state (bool _state) {
		if (get_permission ().allowed && _state != guest_session_state) {
			string arg = "";
			if (!_state)
				arg = "--off";
			else if (_state)
				arg = "--on";

			string output;
			int status;

			try {
				Process.spawn_sync (null, 
					{"sudo", "/usr/lib/x86_64-linux-gnu/switchboard/system/pantheon-useraccounts/guest-session-toggle", arg}, 
					Environ.get (),
					SpawnFlags.SEARCH_PATH,
					null,
					out output,
					null,
					out status);

				if (output == "")
					guest_session_state = _state;
			} catch (Error e) {
				warning (e.message);
			}
		}
	}
}
