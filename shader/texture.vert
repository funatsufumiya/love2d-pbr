uniform mat4 projectionMatrix; 
uniform mat4 viewMatrix;       
uniform mat4 modelMatrix;     
uniform mat3 normalMatrix;
uniform bool isCanvasEnabled;  

attribute vec3 VertexNormal;

varying vec4 screenPosition;
varying vec3 WorldPos;
varying vec3 Normal;

vec4 position(mat4 transformProjection, vec4 vertexPosition) {
    WorldPos = vec3(modelMatrix * vertexPosition);
    screenPosition = projectionMatrix * viewMatrix * vec4(WorldPos,1.0);
    Normal = normalMatrix * VertexNormal;
    //Normal = VertexNormal;
    // Flip Y when rendering to a Canvas (Love2D coordinate convention)
    if (isCanvasEnabled) {
        screenPosition.y *= -1.0;
    }
    return screenPosition;
}
