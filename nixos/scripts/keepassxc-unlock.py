#!/usr/bin/env python3
"""Unlock an existing KeePassXC GUI database from an SSH terminal.

Usage: keepassxc-unlock DATABASE [--keyfile KEYFILE] [--diagnose]
       keepassxc-unlock --status
       keepassxc-unlock --lock

The command resets matching Quick Unlock credentials through AT-SPI, then sends
the master password to KeePassXC over the desktop user's D-Bus session.
"""

import argparse
import configparser
from dataclasses import dataclass
import getpass
import os
from pathlib import Path
import subprocess
import sys
import warnings

import dbus


# KeePassXC's application interface and Secret Service share the session bus.
# AT-SPI uses a separate bus whose address must be obtained from org.a11y.Bus.
KEEPASSXC_SERVICE = "org.keepassxc.KeePassXC.MainWindow"
KEEPASSXC_PATH = "/keepassxc"
DBUS_PROPERTIES = "org.freedesktop.DBus.Properties"
ATSPI_ACCESSIBLE = "org.a11y.atspi.Accessible"
ATSPI_ACTION = "org.a11y.atspi.Action"
SECRETS_SERVICE = "org.freedesktop.secrets"
SECRETS_PATH = "/org/freedesktop/secrets"

# An accessible object is identified by both its bus name and object path.
AccessibleRef = tuple[str, str]


@dataclass
class AccessibleNode:
    """The UI metadata needed to match a Quick Unlock page."""

    parent: AccessibleRef | None
    role: str
    label: str
    children: list[AccessibleRef]


def get_property(bus, reference, interface, name):
    """Read one D-Bus property rather than retrieving unrelated properties."""
    return bus.call_blocking(
        *reference, DBUS_PROPERTIES, "Get", "ss", (interface, name), timeout=5
    )


def accessible_call(bus, reference, method):
    """Call an argument-free AT-SPI Accessible method."""
    return bus.call_blocking(
        *reference, ATSPI_ACCESSIBLE, method, "", (), timeout=5
    )


def connection_pid(bus, name):
    """Ask the bus daemon which process owns a connection."""
    return bus.call_blocking(
        "org.freedesktop.DBus", "/org/freedesktop/DBus",
        "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", (name,),
    )


def find_accessibility_application(session, owner):
    """Find this KeePassXC process on the separate accessibility bus."""
    address = session.call_blocking(
        "org.a11y.Bus", "/org/a11y/bus", "org.a11y.Bus", "GetAddress", "", (),
    )
    accessibility = dbus.bus.BusConnection(address)
    registry = ("org.a11y.atspi.Registry", "/org/a11y/atspi/accessible/root")
    applications = accessible_call(accessibility, registry, "GetChildren")

    # Unique bus names are only meaningful on their own bus. Matching the PID
    # ties the accessibility application to the actual KeePassXC D-Bus owner.
    pid = connection_pid(session, owner)
    matches = []
    for name, path in applications:
        try:
            if connection_pid(accessibility, name) == pid:
                matches.append((str(name), str(path)))
        except dbus.DBusException as error:
            # An unrelated application can exit after the registry was read.
            if error.get_dbus_name() != "org.freedesktop.DBus.Error.NameHasNoOwner":
                raise

    if len(matches) != 1:
        raise RuntimeError("Cannot uniquely identify KeePassXC on the accessibility bus")
    return accessibility, matches[0]


def read_accessibility_tree(bus, root):
    """Capture widget relationships and labels, without reading input values."""
    nodes = {}
    pending = [(root, None)]
    while pending:
        reference, parent = pending.pop()
        if reference in nodes:
            continue

        role = str(accessible_call(bus, reference, "GetRoleName"))
        label = ""
        if role in {"label", "push button"}:
            label = str(get_property(bus, reference, ATSPI_ACCESSIBLE, "Name"))
        children = [
            (str(name), str(path))
            for name, path in accessible_call(bus, reference, "GetChildren")
        ]
        nodes[reference] = AccessibleNode(parent, role, label, children)
        pending.extend((child, reference) for child in children)
    return nodes


def is_target_quick_unlock_page(nodes, button, database):
    """Match the specific KeePassXC page containing this Cancel button.

    DatabaseOpenWidget contains a filename label and a stacked widget. The
    Quick Unlock page inside that stack contains Unlock Database and Cancel.
    A generic Cancel button elsewhere in the application is not a match.
    """
    page = nodes.get(button.parent)
    if page is None or not any(
        nodes[child].role == "push button"
        and nodes[child].label == "Unlock Database"
        for child in page.children
    ):
        return False

    stack = nodes.get(page.parent)
    if stack is None or stack.role != "layered pane":
        return False
    database_widget = nodes.get(stack.parent)
    if database_widget is None:
        return False

    # Use the filename label in this database widget, not the window title or
    # a label from another tab. Resolve symlinks just as the supplied path is.
    return any(
        nodes[child].role == "label"
        and nodes[child].label.startswith("/")
        and Path(nodes[child].label).resolve() == database
        for child in database_widget.children
    )


def find_cancel_actions(bus, nodes, database):
    """Return Quick Unlock reset actions belonging to the target database."""
    matches = []
    for reference, node in nodes.items():
        if node.role != "push button" or node.label != "Cancel":
            continue
        if not is_target_quick_unlock_page(nodes, node, database):
            continue

        actions = bus.call_blocking(
            *reference, ATSPI_ACTION, "GetActions", "", (), timeout=5
        )
        for index, (name, description, shortcut) in enumerate(actions):
            # The Quick Unlock reset button uses Esc. Ordinary dialog Cancel
            # buttons can have the same label but a different action binding.
            if name == "Press" and shortcut == "Esc":
                matches.append((reference, index))
    return matches


def cancel_quick_unlock(session, owner, database):
    """Reset the target's Quick Unlock credentials before supplying a password."""
    accessibility, root = find_accessibility_application(session, owner)
    nodes = read_accessibility_tree(accessibility, root)
    matches = find_cancel_actions(accessibility, nodes, database)
    if not matches:
        print("Quick Unlock: no matching reset action found.", flush=True)
        return
    if len(matches) != 1:
        raise RuntimeError("Multiple matching Quick Unlock pages; no button was pressed")

    # KeePassXC's resetQuickUnlock() is safe even when its page is hidden or no
    # cached key exists. Resetting prevents its cached-key branch from invoking
    # Polkit instead of using the password passed to openDatabase().
    reference, index = matches[0]
    print("Quick Unlock: resetting the target database's cached credentials...", flush=True)
    accepted = accessibility.call_blocking(
        *reference, ATSPI_ACTION, "DoAction", "i", (index,), timeout=5
    )
    if not accepted:
        raise RuntimeError("Quick Unlock reset action was rejected")
    print("Quick Unlock: reset action completed; continuing with the master password.", flush=True)


def show_status(session, stage):
    """Report the exposed collections' lock states without retrieving secrets."""
    collections = get_property(
        session, (SECRETS_SERVICE, SECRETS_PATH),
        "org.freedesktop.Secret.Service", "Collections",
    )
    print(f"Secret Service status ({stage}):", flush=True)
    lock_states = []
    for path in collections:
        locked = get_property(
            session, (SECRETS_SERVICE, path),
            "org.freedesktop.Secret.Collection", "Locked",
        )
        lock_states.append(bool(locked))
        print(f"  {path}: {'LOCKED' if locked else 'UNLOCKED'}", flush=True)
    if not collections:
        print("  No exposed collections.", flush=True)
    return lock_states


def validate_credentials(database, password, keyfile):
    """Verify credentials independently of GUI state using a read-only command."""
    print("Validating credentials with CLI...", flush=True)
    command = ["keepassxc-cli", "db-info"]
    if keyfile:
        command.extend(["--key-file", keyfile])
    command.append(str(database))

    # Send the password on stdin rather than exposing it in command arguments.
    # Discard database metadata, but retain errors for diagnosing unlock failures.
    result = subprocess.run(
        command, input=password + "\n", encoding="utf-8",
        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=120,
    )
    if result.returncode:
        raise RuntimeError(f"CLI credential validation: FAILED\n{result.stderr.strip()}")
    print("CLI credential validation: PASSED", flush=True)


def unlock_database(session, owner, database, password, keyfile):
    """Send the explicit password-and-keyfile overload to the existing GUI."""
    print("Calling GUI unlock interface...", flush=True)
    # The 'sss' signature selects the overload with three strings. The path
    # identifies an existing database tab; an empty keyfile means password-only.
    session.call_blocking(
        owner, KEEPASSXC_PATH, KEEPASSXC_SERVICE, "openDatabase", "sss",
        (str(database), password, keyfile), timeout=120,
    )
    print("GUI D-Bus call returned; checking lock status.", flush=True)


def lock_databases(session, owner):
    """Lock all databases currently open in the KeePassXC GUI."""
    print("Locking all open databases...", flush=True)
    session.call_blocking(
        owner, KEEPASSXC_PATH, KEEPASSXC_SERVICE, "lockAllDatabases", "", (), timeout=30,
    )
    print("KeePassXC lock request completed; checking lock status.", flush=True)


def parse_args():
    parser = argparse.ArgumentParser(prog="keepassxc-unlock", description=__doc__)
    parser.add_argument("database", type=Path, nargs="?", help="Path to the KDBX database")
    parser.add_argument("--keyfile", type=Path, help="Native KDBX key file, if required")
    parser.add_argument(
        "--diagnose", action="store_true",
        help="Validate credentials with the read-only CLI db-info command first",
    )
    parser.add_argument(
        "--status", action="store_true",
        help="Only read Secret Service lock status; no password required",
    )
    parser.add_argument(
        "--lock", action="store_true",
        help="Lock all databases currently open in KeePassXC",
    )
    args = parser.parse_args()
    if args.lock and (args.status or args.database or args.keyfile or args.diagnose):
        parser.error("--lock cannot be combined with --status, a database, --keyfile, or --diagnose")
    if not args.status and args.database is None:
        if args.lock:
            return args
        state_file = Path("~/.local/state/keepassxc/keepassxc.ini").expanduser()
        config = configparser.ConfigParser()
        loaded = config.read(state_file)
        database = config.get("General", "LastActiveDatabase", fallback="")
        if not loaded or not database:
            parser.error(f"database not specified and active database was not found in {state_file}")
        args.database = Path(database)
    return args


def main():
    args = parse_args()
    # An SSH shell must connect to the desktop user's existing bus, rather than
    # creating a new session bus with no KeePassXC instance on it.
    bus_address = f"unix:path=/run/user/{os.getuid()}/bus"
    os.environ["DBUS_SESSION_BUS_ADDRESS"] = bus_address
    session = dbus.SessionBus()
    show_status(session, "before")
    if args.status:
        return
    if args.lock:
        owner = session.get_name_owner(KEEPASSXC_SERVICE)
        lock_databases(session, owner)
        show_status(session, "after")
        return

    database = args.database.expanduser().resolve(strict=True)
    keyfile = str(args.keyfile.expanduser().resolve(strict=True)) if args.keyfile else ""
    owner = session.get_name_owner(KEEPASSXC_SERVICE)
    cancel_quick_unlock(session, owner, database)

    # Fail rather than let getpass fall back to echoing input without a usable
    # terminal. The standard getpass implementation handles the password prompt.
    warnings.simplefilter("error", getpass.GetPassWarning)
    password = getpass.getpass("KeePassXC master password: ")
    print("Password input received.", flush=True)
    if args.diagnose:
        validate_credentials(database, password, keyfile)

    unlock_database(session, owner, database, password, keyfile)
    # openDatabase() has no success result. Report Secret Service state instead
    # of treating a successful D-Bus method return as proof of an unlocked vault.
    lock_states = show_status(session, "after")
    if not lock_states:
        raise RuntimeError("GUI D-Bus call returned, but no Secret Service collection is exposed")
    if all(lock_states):
        raise RuntimeError("GUI D-Bus call returned, but all Secret Service collections remain locked")
    print(f"Verify gh access with:\n  DBUS_SESSION_BUS_ADDRESS={bus_address} gh auth status")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, dbus.DBusException, getpass.GetPassWarning, subprocess.TimeoutExpired) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print("Cancelled.", file=sys.stderr)
        sys.exit(130)
