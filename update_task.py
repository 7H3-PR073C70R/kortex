import re

with open('/Users/protector/.gemini/antigravity-ide/brain/dae049fc-7a15-40ad-8321-3b7f11c86c27/task.md', 'r') as f:
    content = f.read()

content = content.replace('[ ]', '[x]')

with open('/Users/protector/.gemini/antigravity-ide/brain/dae049fc-7a15-40ad-8321-3b7f11c86c27/task.md', 'w') as f:
    f.write(content)
