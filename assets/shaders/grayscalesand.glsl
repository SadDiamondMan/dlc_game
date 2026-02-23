uniform vec3 sand1;
uniform vec3 sand2;
uniform vec3 sand3;
uniform vec3 sand4;
uniform vec3 sandcol;
        
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords){
    vec4 col = Texel(texture, texture_coords);
    vec3 finalcol = vec3(dot(col.rgb, vec3(0.3, 0.59, 0.11)));
	
	vec3 col255 = floor(col.rgb*255.0);
	
	if (
	(col255.rgb == sand1) 
	|| (col255.rgb  == sand2) 
	|| (col255.rgb  == sand3)
	|| (col255.rgb  == sand4)
	) 
	{
		finalcol = sandcol;
	}

    return vec4(finalcol, col.a);
}