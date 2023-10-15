shader_type spatial;
render_mode cull_disabled;

#include "HairBxDF.gdshaderinc"

group_uniforms Color;
uniform vec3 root_color : source_color = vec3(0,0,0);
uniform vec3 tip_color : source_color = vec3(0,0,0);
uniform sampler2D diffuse_texture : source_color;
uniform vec3 primary_color : source_color = vec3(1.0);
uniform vec3 secondary_color : source_color = vec3(1.0);

group_uniforms SpecularHighlights;
uniform float primary_shift : hint_range(-4, 4) = 0.0;
uniform float secondary_shift : hint_range(-4, 4) = 0.5;
uniform sampler2D specular_shift : hint_default_white;
uniform float specular_power : hint_range(0, 50) = 20;
uniform float specular_width : hint_range(0, 1) = 0.5;
uniform float specular_scale : hint_range(0, 1) = 0.3;

group_uniforms Structural;
uniform float scatter : hint_range(0.0, 5.0, 0.01) = 1.0;
uniform bool use_diffuse_texture;
uniform sampler2D property_tex : hint_default_white;
uniform sampler2D hair_normal_map : hint_roughness_normal;

varying vec3 binormal;

void fragment(){
	mediump vec4 property = texture(property_tex, UV);
	vec3 basecolor = mix(root_color.rgb, tip_color.rgb, property.b);
	if(use_diffuse_texture){
		vec3 base_hair = texture(diffuse_texture, UV).rgb;
		ALBEDO = base_hair;
	} else {
		ALBEDO = basecolor;
	}
	NORMAL_MAP = texture(hair_normal_map, UV).rgb;
	AO = property.r;
	ALPHA = property.a;
	ALPHA_HASH_SCALE = 0.1;
	binormal = BINORMAL;
}

void light()
{
	float shift_tex = texture(specular_shift, UV).r - 0.5;
	vec3 N = normalize(NORMAL);
	vec3 B = normalize(binormal);
	vec3 V = normalize(VIEW);
	vec3 L = normalize(LIGHT);

	vec3 ambientdiffuse = getAmbientAndDiffuse(ALBEDO, scatter, N, L, V, 1.0);
	vec3 specular = getSpecularKajiyaKay(shift_tex, primary_color, primary_shift, secondary_color, secondary_shift, N, B, V, L, specular_power, specular_width, specular_scale);

	DIFFUSE_LIGHT += ambientdiffuse * LIGHT_COLOR * ATTENUATION;
	SPECULAR_LIGHT += specular * LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT;
}