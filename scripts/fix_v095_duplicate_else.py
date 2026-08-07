from pathlib import Path
p = Path('Sources/Transport/UnifiedMediaTransportSession.swift')
s = p.read_text()
duplicate = '''            } else {
                var slowStartupRefreshUsed = false
            } else {
                var slowStartupRefreshUsed = false
'''
single = '''            } else {
                var slowStartupRefreshUsed = false
'''
if duplicate in s:
    p.write_text(s.replace(duplicate, single, 1))
elif single not in s:
    raise SystemExit('Expected sequential/urgent branch boundary not found')
