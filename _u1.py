import io
p='tools/shot_ch02_story_ui.gd'
s=io.open(p,encoding='utf-8').read()
old=s[s.index('		var sp := get_viewport().world_3d.direct_space_state'):s.index('	var hub3: Node = scene.get("workshop_hub")')]
s=s.replace(old,'',1)
s=s.replace('		await _shot("living_wide", hp + Vector3(2.0, 9.0, 26.0), hp + Vector3(2.0, 0.0, 4.0))',
            '		await _shot("living_wide", hp + Vector3(2.0, 15.0, 40.0), hp + Vector3(2.0, 0.0, 10.0))',1)
io.open(p,'w',encoding='utf-8',newline='\n').write(s)
print('ok')
