uniform mat4 projectionMatrix; 
uniform mat4 viewMatrix;       
uniform mat4 modelMatrix;     
uniform mat3 normalMatrix;
// Workaround flag: when rendering into a Canvas, LÖVE flips the Y
// coordinate. We expose this as a uniform so vertex shader can flip
// the screen-space Y consistently. This is a workaround for Canvas
// coordinate convention differences and not a fundamental shader change.
uniform int isCanvasEnabled;  

attribute vec3 VertexNormal;

varying vec4 screenPosition;
varying vec3 WorldPos;
varying vec3 Normal;

vec4 position(mat4 transformProjection, vec4 vertexPosition) {
    WorldPos = vec3(modelMatrix * vertexPosition);
    screenPosition = projectionMatrix * viewMatrix * vec4(WorldPos,1.0);
    Normal = normalMatrix * VertexNormal;
    //Normal = VertexNormal;
    
    // Flip Y when rendering to a Canvas (LÖVE coordinate convention).
    // This is a workaround to keep derivative-based TBN calculations
    // consistent between Canvas and direct screen rendering.
    if (isCanvasEnabled == 1) {
        screenPosition.y *= -1.0;
    }
    return screenPosition;
}
