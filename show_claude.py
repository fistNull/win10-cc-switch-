import sqlite3, os, json
db = os.path.join(os.environ['USERPROFILE'], '.cc-switch', 'cc-switch.db')
conn = sqlite3.connect(db)
cur = conn.cursor()

print('=== claude providers ===')
for r in cur.execute("SELECT id, name, is_current, settings_config FROM providers WHERE app_type='claude'").fetchall():
    print(f'id={r[0]} name={r[1]} is_current={r[2]}')
    s = json.loads(r[3]) if r[3] else {}
    print(f'  env={s.get("env")}')
    print(f'  auth keys={list(s.get("auth",{}).keys())}')
    print()

print('=== claude endpoints ===')
for r in cur.execute("SELECT provider_id, app_type, url FROM provider_endpoints WHERE app_type='claude'").fetchall():
    print(r)

print('=== settings ===')
for r in cur.execute("SELECT key, value FROM settings WHERE key LIKE '%rovider%'").fetchall():
    print(r)
