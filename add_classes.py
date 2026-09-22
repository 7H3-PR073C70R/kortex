with open('web_landing/index.html', 'r') as f:
    content = f.read()

content = content.replace('class="pillar-visual-card"', 'class="pillar-visual-card float-animated"')
content = content.replace('class="differentiator-card reveal-on-scroll delay-1"', 'class="differentiator-card reveal-on-scroll delay-1 float-animated"')
content = content.replace('class="differentiator-card reveal-on-scroll delay-2"', 'class="differentiator-card reveal-on-scroll delay-2 float-animated"')

with open('web_landing/index.html', 'w') as f:
    f.write(content)
