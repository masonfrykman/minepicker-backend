import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'config.dart';
import 'dart:io';

String getAccountsDBFilePath() {
  if (config["CustomSQLiteDBFile"] != null) {
    return config["CustomSQLiteDBFile"]!;
  }
  // now attempt to infer from RootMinecraftDirectory and check.
  final inference = "${config["RootMinecraftDirectory"]}accounts.sqlite3";
  if (!File(inference).existsSync()) {
    throw "Failed to get a valid accounts database file path.";
  }
  return inference;
}

bool authenticateUser(String username, String password) {
  print("USER AUTH: $username; [redacted pwd]");
  if (username.trim().isEmpty || password.trim().isEmpty) {
    return false;
  }

  final db = sqlite3.open(getAccountsDBFilePath());

  final dbchck = db.prepare('SELECT * FROM accounts WHERE username = ?');

  final selectExec = dbchck.select([username]);

  if (selectExec.length != 1) {
    return false;
  }

  db.dispose();
  dbchck.dispose();
  if (selectExec.first["password"] == password) {
    return true;
  }
  return false;
}

bool createUser(String username, String password) {
  print("New User Creation Attempt: $username; $password");
  if (username.trim().isEmpty || password.trim().isEmpty) {
    return false;
  }

  final db = sqlite3.open(getAccountsDBFilePath());

  final dbfllr =
      db.prepare("INSERT INTO accounts (username, password) VALUES (?, ?)");

  dbfllr.execute([username, password]);

  dbfllr.dispose();

  db.dispose();

  return true;
}

bool deleteUser(String username) {
  print("Delete User Attempt: $username");

  if (username.trim().isEmpty) {
    return false;
  }

  final db = sqlite3.open(getAccountsDBFilePath());

  final dbfllr = db.prepare("DELETE FROM accounts WHERE username = ?");

  dbfllr.execute([username]);

  dbfllr.dispose();

  db.dispose();

  return true;
}

bool changePassword(String username, String oldPassword, String newPassword) {
  print("CHANGE PASSWORD ATTEMPT: $username");
  print("$oldPassword");

  if (username.trim().isEmpty ||
      oldPassword.trim().isEmpty ||
      newPassword.trim().length <= 4) {
    return false;
  }

  final db = sqlite3.open(getAccountsDBFilePath());

  final dbfllr = db.prepare("SELECT * FROM accounts WHERE username = ?");

  final selection = dbfllr.select([username]);

  if (selection.first["password"] != oldPassword) {
    print("Incorrect.");
    return false;
  }

  final dbfllr2 =
      db.prepare("REPLACE INTO accounts (username, password) VALUES (?, ?)");

  dbfllr2.execute([username, newPassword]);

  dbfllr.dispose();
  db.dispose();
  return true;
}

void createAccountsDB() {
  final getPath = getAccountsDBFilePath();

  if (!File(getPath).existsSync()) {
    File(getPath).createSync(recursive: true);
  }

  final db = sqlite3.open(getPath);

  db.execute('''CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER NOT NULL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL
  )''');

  db.execute('''CREATE UNIQUE INDEX IF NOT EXISTS accounts_usrnm_ui
  ON accounts (username)''');

  db.dispose();
}

void safelyPrintNewCredentialsIfTableEmpty() {
  final getPath = getAccountsDBFilePath();

  if (!File(getPath).existsSync()) {
    throw "Failed to open DB for authentication";
  }

  final db = sqlite3.open(getPath);

  final selection = db.select("SELECT * FROM accounts");

  if (selection.isEmpty) {
    final rng = Random().nextInt(999999);

    createUser("unsafeTemporaryAccountReplaceMe", "$rng");

    print(
        "WARNING: Accounts DB was empty! Created the following user account for creating a new unique user.");
    print(
        "!!! DO NOT KEEP THIS ACCOUNT FOR MORE THAN CREATING A NEW ACCOUNT !!!");
    print("Username: unsafeTemporaryAccountReplaceMe");
    print("Password: $rng");
  }
}
