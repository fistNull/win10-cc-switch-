import sqlite3, os
db = os.path.join(os.environ['USERPROFILE'], '.cc-switch', 'cc-switch.db')
conn = sqlite3.connect(db)
for r in conn.execute("SELECT name, sql FROM sqlite_master WHERE type='table'").fetchall():
    print(r[0])
    print(r[1])
    print()
