// OpenGL 3.3+

#include "ruby2d.h"

// Skip this file if OpenGL ES
#if !GLES

static GLuint vbo;  // our primary vertex buffer object (VBO)
static GLuint vboSize;  // size of the VBO in bytes
static GLfloat *vboData;  // pointer to the VBO data
static GLfloat *vboDataCurrent;  // pointer to the data for the current vertices
static GLuint vboDataIndex = 0;  // index of the current object being rendered
static GLuint vboObjCapacity = 2500;  // number of objects the VBO can store
static GLuint shaderProgram;  // triangle shader program
static GLuint texShaderProgram;  // texture shader program
static GLuint indices[] =  // indices for rendering textured quads
  { 0, 1, 2,
    2, 3, 0 };


/*
 * Applies the projection matrix
 */
void R2D_GL3_ApplyProjection(GLfloat orthoMatrix[16]) {

  // Use the program object
  glUseProgram(shaderProgram);

  // Apply the projection matrix to the triangle shader
  glUniformMatrix4fv(
    glGetUniformLocation(shaderProgram, "u_mvpMatrix"),
    1, GL_FALSE, orthoMatrix
  );

  // Use the texture program object
  glUseProgram(texShaderProgram);

  // Apply the projection matrix to the texture shader
  glUniformMatrix4fv(
    glGetUniformLocation(texShaderProgram, "u_mvpMatrix"),
    1, GL_FALSE, orthoMatrix
  );
}


/*
 * Initalize OpenGL
 */
int R2D_GL3_Init() {

  // Enable transparency
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  // Vertex shader source string
  GLchar vertexSource[] =
    "#version 150 core\n"  // shader version

    "uniform mat4 u_mvpMatrix;"  // projection matrix

    // Input attributes to the vertex shader
    "in vec4 position;"  // position value
    "in vec4 color;"     // vertex color
    "in vec2 texcoord;"  // texture coordinates

    // Outputs to the fragment shader
    "out vec4 Color;"     // vertex color
    "out vec2 Texcoord;"  // texture coordinates

    "void main() {"
    // Send the color and texture coordinates right through to the fragment shader
    "  Color = color;"
    "  Texcoord = texcoord;"
    // Transform the vertex position using the projection matrix
    "  gl_Position = u_mvpMatrix * position;"
    "}";

  // Fragment shader source string
  GLchar fragmentSource[] =
    "#version 150 core\n"  // shader version
    "in vec4 Color;"       // input color from vertex shader
    "out vec4 outColor;"   // output fragment color

    "void main() {"
    "  outColor = Color;"  // pass the color right through
    "}";

  // Fragment shader source string for textures
  GLchar texFragmentSource[] =
    "#version 150 core\n"     // shader version
    "in vec4 Color;"          // input color from vertex shader
    "in vec2 Texcoord;"       // input texture coordinates
    "out vec4 outColor;"      // output fragment color
    "uniform sampler2D tex;"  // 2D texture unit

    "void main() {"
    // Apply the texture unit, texture coordinates, and color
    "  outColor = texture(tex, Texcoord) * Color;"
    "}";

  // Create a vertex array object
  GLuint vao;
  glGenVertexArrays(1, &vao);
  glBindVertexArray(vao);

  // Create a vertex buffer object and allocate data
  glGenBuffers(1, &vbo);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  vboSize = vboObjCapacity * sizeof(GLfloat) * 24;
  vboData = (GLfloat *) malloc(vboSize);
  vboDataCurrent = vboData;

  // Create an element buffer object
  GLuint ebo;
  glGenBuffers(1, &ebo);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);

  // Load the vertex and fragment shaders
  GLuint vertexShader      = R2D_GL_LoadShader(  GL_VERTEX_SHADER,      vertexSource, "GL3 Vertex");
  GLuint fragmentShader    = R2D_GL_LoadShader(GL_FRAGMENT_SHADER,    fragmentSource, "GL3 Fragment");
  GLuint texFragmentShader = R2D_GL_LoadShader(GL_FRAGMENT_SHADER, texFragmentSource, "GL3 Texture Fragment");

  // Triangle Shader //

  // Create the shader program object
  shaderProgram = glCreateProgram();

  // Check if program was created successfully
  if (shaderProgram == 0) {
    R2D_GL_PrintError("Failed to create shader program");
    return GL_FALSE;
  }

  // Attach the shader objects to the program object
  glAttachShader(shaderProgram, vertexShader);
  glAttachShader(shaderProgram, fragmentShader);

  // Bind the output color variable to the fragment shader color number
  glBindFragDataLocation(shaderProgram, 0, "outColor");

  // Link the shader program
  glLinkProgram(shaderProgram);

  // Check if linked
  R2D_GL_CheckLinked(shaderProgram, "GL3 shader");

  // Specify the layout of the position vertex data...
  GLint posAttrib = glGetAttribLocation(shaderProgram, "position");
  glEnableVertexAttribArray(posAttrib);
  glVertexAttribPointer(posAttrib, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), 0);

  // ...and the color vertex data
  GLint colAttrib = glGetAttribLocation(shaderProgram, "color");
  glEnableVertexAttribArray(colAttrib);
  glVertexAttribPointer(colAttrib, 4, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));

  // Texture Shader //

  // Create the texture shader program object
  texShaderProgram = glCreateProgram();

  // Check if program was created successfully
  if (texShaderProgram == 0) {
    R2D_GL_PrintError("Failed to create shader program");
    return GL_FALSE;
  }

  // Attach the shader objects to the program object
  glAttachShader(texShaderProgram, vertexShader);
  glAttachShader(texShaderProgram, texFragmentShader);

  // Bind the output color variable to the fragment shader color number
  glBindFragDataLocation(texShaderProgram, 0, "outColor");

  // Link the shader program
  glLinkProgram(texShaderProgram);

  // Check if linked
  R2D_GL_CheckLinked(texShaderProgram, "GL3 texture shader");

  // Specify the layout of the position vertex data...
  posAttrib = glGetAttribLocation(texShaderProgram, "position");
  glVertexAttribPointer(posAttrib, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), 0);
  glEnableVertexAttribArray(posAttrib);

  // ...and the color vertex data...
  colAttrib = glGetAttribLocation(texShaderProgram, "color");
  glVertexAttribPointer(colAttrib, 4, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));
  glEnableVertexAttribArray(colAttrib);

  // ...and the texture coordinates
  GLint texAttrib = glGetAttribLocation(texShaderProgram, "texcoord");
  glVertexAttribPointer(texAttrib, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), (void*)(6 * sizeof(GLfloat)));
  glEnableVertexAttribArray(texAttrib);

  // Clean up
  glDeleteShader(vertexShader);
  glDeleteShader(fragmentShader);
  glDeleteShader(texFragmentShader);

  // If successful, return true
  return GL_TRUE;
}


/*
 * Render the vertex buffer and reset it
 */
void R2D_GL3_FlushBuffers() {

  // Use the triangle shader program
  glUseProgram(shaderProgram);

  // Bind to the vertex buffer object and update its data
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, vboSize, NULL, GL_DYNAMIC_DRAW);
  glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(GLfloat) * vboDataIndex * 24, vboData);

  // Render all the triangles in the buffer
  glDrawArrays(GL_TRIANGLES, 0, (GLsizei)(vboDataIndex * 3));

  // Reset the buffer object index and data pointer
  vboDataIndex = 0;
  vboDataCurrent = vboData;
}


/*
 * Draw triangle
 */
void R2D_GL3_DrawTriangle(GLfloat x1, GLfloat y1,
                          GLfloat r1, GLfloat g1, GLfloat b1, GLfloat a1,
                          GLfloat x2, GLfloat y2,
                          GLfloat r2, GLfloat g2, GLfloat b2, GLfloat a2,
                          GLfloat x3, GLfloat y3,
                          GLfloat r3, GLfloat g3, GLfloat b3, GLfloat a3) {

  // If buffer is full, flush it
  if (vboDataIndex >= vboObjCapacity) R2D_GL3_FlushBuffers();

  // Set the triangle data into a formatted array
  GLfloat vertices[] =
    { x1, y1, r1, g1, b1, a1, 0, 0,
      x2, y2, r2, g2, b2, a2, 0, 0,
      x3, y3, r3, g3, b3, a3, 0, 0 };

  // Copy the vertex data into the current position of the buffer
  memcpy(vboDataCurrent, vertices, sizeof(vertices));

  // Increment the buffer object index and the vertex data pointer for next use
  vboDataIndex++;
  vboDataCurrent = (GLfloat *)((char *)vboDataCurrent + (sizeof(GLfloat) * 24));
}


/*
 * Draw a texture
 */
static void R2D_GL3_DrawTexture(int x, int y, int w, int h,
                                GLfloat angle, GLfloat rx, GLfloat ry,
                                GLfloat r, GLfloat g, GLfloat b, GLfloat a,
                                GLfloat tx1, GLfloat ty1, GLfloat tx2, GLfloat ty2,
                                GLfloat tx3, GLfloat ty3, GLfloat tx4, GLfloat ty4,
                                GLuint texture_id) {

  // Currently, textures are not buffered, so we have to flush all buffers so
  // textures get rendered in the correct Z order
  R2D_GL3_FlushBuffers();

  // Set up the vertex points
  R2D_GL_Point v1 = { .x = x,     .y = y     };
  R2D_GL_Point v2 = { .x = x + w, .y = y     };
  R2D_GL_Point v3 = { .x = x + w, .y = y + h };
  R2D_GL_Point v4 = { .x = x,     .y = y + h };

  // Rotate vertices
  if (angle != 0) {
    v1 = R2D_RotatePoint(v1, angle, rx, ry);
    v2 = R2D_RotatePoint(v2, angle, rx, ry);
    v3 = R2D_RotatePoint(v3, angle, rx, ry);
    v4 = R2D_RotatePoint(v4, angle, rx, ry);
  }

  // Set the textured quad data into a formatted array
  GLfloat vertices[] =
  //  vertex coords | colors      | x, y texture coords
    { v1.x, v1.y,     r, g, b, a,   tx1, ty1,    // Top-left
      v2.x, v2.y,     r, g, b, a,   tx2, ty2,    // Top-right
      v3.x, v3.y,     r, g, b, a,   tx3, ty3,    // Bottom-right
      v4.x, v4.y,     r, g, b, a,   tx4, ty4 };  // Bottom-left

  // Use the texture shader program
  glUseProgram(texShaderProgram);

  // Bind the texture using the provided ID
  glBindTexture(GL_TEXTURE_2D, texture_id);

  // Create and Initialize the vertex data and array indices
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

  // Render the textured quad
  glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}


/*
 * Draw a texture (New method with vertices pre-calculated)
 */
void R2D_GL3_NewDrawTexture(GLfloat coordinates[], GLfloat texture_coordinates[], GLfloat color[], int texture_id) {
  // Currently, textures are not buffered, so we have to flush all buffers so
  // textures get rendered in the correct Z order
  R2D_GL3_FlushBuffers();

  // Use the texture shader program
  glUseProgram(texShaderProgram);

  // Bind the texture using the provided ID
  glBindTexture(GL_TEXTURE_2D, texture_id);

  GLfloat vertices[32] = {
    coordinates[0], coordinates[1], color[0], color[1], color[2], color[3], texture_coordinates[0], texture_coordinates[1],
    coordinates[2], coordinates[3], color[0], color[1], color[2], color[3], texture_coordinates[2], texture_coordinates[3],
    coordinates[4], coordinates[5], color[0], color[1], color[2], color[3], texture_coordinates[4], texture_coordinates[5],
    coordinates[6], coordinates[7], color[0], color[1], color[2], color[3], texture_coordinates[6], texture_coordinates[7],
  };

  // Create and Initialize the vertex data and array indices
  glBufferData(GL_ARRAY_BUFFER, 32 * sizeof(GLfloat), vertices, GL_STATIC_DRAW);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

  // Render the textured quad
  glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}


#endif