//Credits
//https://github.com/maajor/Marschner-Hair-Unity
shader_type spatial;
render_mode cull_disabled;

#include "MarschnerBSDF.gdshaderinc"

group_uniforms Color;
uniform vec3 root_color : source_color = vec3(0,0,0);
uniform vec3 tip_color : source_color = vec3(0,0,0);
uniform bool use_diffuse_texture = false;
uniform sampler2D diffuse_tex : source_color;

group_uniforms Structural;
uniform sampler2D property_tex : hint_default_white;
uniform float scatter : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float tangent_amplitude : hint_range(0.0, 0.1, 0.01) = 0.1;
uniform bool use_flow_map = false;
uniform sampler2D flowmap : hint_default_white;

group_uniforms SpecularHighlights;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float roughness : hint_range(0.0, 1.0, 0.01)  = 0.5;

varying vec3 binormal;

void fragment(){
	vec3 albedo_texture = texture(diffuse_tex, UV).rgb;
	mediump vec4 property = texture(property_tex, UV);
	vec3 basecolor = mix(root_color.rgb, tip_color.rgb, property.b);
	if(use_diffuse_texture){
		ALBEDO = albedo_texture;
	} else {
		ALBEDO = basecolor;
	}
	SPECULAR = specular;
	ROUGHNESS = roughness;
	//We need to have anisotropy enabled to get an anisotropy IBL
	ANISOTROPY = 1.0;
	ALPHA = property.a;
	//ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_HASH_SCALE = 0.01;
	if(use_flow_map){
		mediump vec3 flow = texture(flowmap, UV).rgb;
		BINORMAL.xz += flow.rb * 2.0f - 1.0;
	} else {
		// Automatic Tangent Mapping
		float offset = property.g * 2.0 * tangent_amplitude - tangent_amplitude;
		BINORMAL.z += offset;
	}
	binormal = BINORMAL;
}

void light(){
	mediump vec3 property = texture(property_tex, UV).rgb;
	mediump vec3 V = normalize(VIEW);
	mediump vec3 N = normalize(NORMAL);
	mediump vec3 B = normalize(binormal);
	vec3 L = normalize(LIGHT);
	float diff = max(0.0, (dot(N, L) + ROUGHNESS) / ((1.0 + ROUGHNESS) * (1.0 + ROUGHNESS))) * (1.0 / PI) * scatter;
	vec3 spec = specular_marschner(ALBEDO, specular, ROUGHNESS, L, V, B);
	
	DIFFUSE_LIGHT += diff * LIGHT_COLOR * ATTENUATION;
	SPECULAR_LIGHT += spec * LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT;
}