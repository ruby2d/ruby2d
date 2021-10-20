// OpenGL ES

#include "ruby2d.h"

#if GLES

static GLuint vbo;  // our primary vertex buffer object (VBO)
static GLuint vboSize;  // size of the VBO in bytes
static GLfloat *vboData;  // pointer to the VBO data
static GLfloat *vboDataCurrent;  // pointer to the data for the current vertices
static GLuint vboDataIndex = 0;  // index of the current object being rendered
static GLuint vboObjCapacity = 7500;  // number of objects the VBO can store
static GLuint verticesTextureIds[7500]; // store the texture_id of each vertices
static GLuint shaderProgram;  // triangle shader program
static GLuint texShaderProgram;  // texture shader program


/*
 * Applies the projection matrix
 */
void R2D_GLES_ApplyProjection(GLfloat orthoMatrix[16]) {

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
int R2D_GLES_Init() {

  // Enable transparency
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  // Vertex shader source string
  GLchar vertexSource[] =
    // uniforms used by the vertex shader
    "uniform mat4 u_mvpMatrix;"   // projection matrix

    // attributes input to the vertex shader
    "attribute vec4 a_position;"  // position value
    "attribute vec4 a_color;"     // input vertex color
    "attribute vec2 a_texcoord;"  // input texture

    // varying variables, input to the fragment shader
    "varying vec4 v_color;"       // output vertex color
    "varying vec2 v_texcoord;"    // output texture

    "void main()"
    "{"
    "  v_color = a_color;"
    "  v_texcoord = a_texcoord;"
    "  gl_Position = u_mvpMatrix * a_position;"
    "}";

  // Fragment shader source string
  GLchar fragmentSource[] =
    #ifdef __EMSCRIPTEN__
    "precision mediump float;"
    #endif
    // input vertex color from vertex shader
    "varying vec4 v_color;"

    "void main()"
    "{"
    "  gl_FragColor = v_color;"
    "}";

  // Fragment shader source string for textures
  GLchar texFragmentSource[] =
    #ifdef __EMSCRIPTEN__
    "precision mediump float;"
    #endif
    // input vertex color from vertex shader
    "varying vec4 v_color;"
    "varying vec2 v_texcoord;"
    "uniform sampler2D s_texture;"

    "void main()"
    "{"
    "  gl_FragColor = texture2D(s_texture, v_texcoord) * v_color;"
    "}";

  // // Create a vertex array object
  // GLuint vao;
  // glGenVertexArrays(1, &vao);
  // glBindVertexArray(vao);

  // Create a vertex buffer object and allocate data
  glGenBuffers(1, &vbo);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  vboSize = vboObjCapacity * sizeof(GLfloat) * 8;
  vboData = (GLfloat *) malloc(vboSize);
  vboDataCurrent = vboData;

  // Create an element buffer object
  GLuint ebo;
  glGenBuffers(1, &ebo);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);

  // Load the vertex and fragment shaders
  GLuint vertexShader      = R2D_GL_LoadShader(  GL_VERTEX_SHADER,      vertexSource, "GLES Vertex");
  GLuint fragmentShader    = R2D_GL_LoadShader(GL_FRAGMENT_SHADER,    fragmentSource, "GLES Fragment");
  GLuint texFragmentShader = R2D_GL_LoadShader(GL_FRAGMENT_SHADER, texFragmentSource, "GLES Texture Fragment");

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

  // Link the shader program
  glLinkProgram(shaderProgram);

  // Check if linked
  R2D_GL_CheckLinked(shaderProgram, "GLES shader");

  // Specify the layout of the position vertex data...
  GLint posAttrib = glGetAttribLocation(shaderProgram, "a_position");
  glEnableVertexAttribArray(posAttrib);
  glVertexAttribPointer(posAttrib, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), 0);

  // ...and the color vertex data
  GLint colAttrib = glGetAttribLocation(shaderProgram, "a_color");
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

  // Link the shader program
  glLinkProgram(texShaderProgram);

  // Check if linked
  R2D_GL_CheckLinked(texShaderProgram, "GLES texture shader");

  // Specify the layout of the position vertex data...
  posAttrib = glGetAttribLocation(texShaderProgram, "a_position");
  glVertexAttribPointer(posAttrib, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), 0);
  glEnableVertexAttribArray(posAttrib);

  // ...and the color vertex data...
  colAttrib = glGetAttribLocation(texShaderProgram, "a_color");
  glVertexAttribPointer(colAttrib, 4, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));
  glEnableVertexAttribArray(colAttrib);

  // ...and the texture coordinates
  GLint texAttrib = glGetAttribLocation(texShaderProgram, "a_texcoord");
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
void R2D_GLES_FlushBuffers() {

  // Bind to the vertex buffer object and update its data
  glBindBuffer(GL_ARRAY_BUFFER, vbo);

  glBufferData(GL_ARRAY_BUFFER, vboSize, NULL, GL_DYNAMIC_DRAW);
  glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(GLfloat) * vboDataIndex * 8, vboData);

  GLuint verticesOffset = 0;
  GLuint lastTextureId = verticesTextureIds[0];

  for (GLuint i = 0; i <= vboDataIndex; i++) {
    if (lastTextureId != verticesTextureIds[i] || i == vboDataIndex) {
      // A texture ID of 0 represents no texture (render a triangle)
      if (lastTextureId == 0) {

        // Use the triangle shader program
        glUseProgram(shaderProgram);

      // A number other than 0 represents a texture_id
      } else {

        // Use the texture shader program
        glUseProgram(texShaderProgram);

        // Bind the texture using the provided ID
        glBindTexture(GL_TEXTURE_2D, lastTextureId);
      }

      glDrawArrays(GL_TRIANGLES, verticesOffset, i - verticesOffset);

      lastTextureId = verticesTextureIds[i];
      verticesOffset = i;
    }
  }

  // Reset the buffer object index and data pointer
  vboDataIndex = 0;
  vboDataCurrent = vboData;
}


/*
 * Draw triangle
 */
void R2D_GLES_DrawTriangle(GLfloat x1, GLfloat y1,
                           GLfloat r1, GLfloat g1, GLfloat b1, GLfloat a1,
                           GLfloat x2, GLfloat y2,
                           GLfloat r2, GLfloat g2, GLfloat b2, GLfloat a2,
                           GLfloat x3, GLfloat y3,
                           GLfloat r3, GLfloat g3, GLfloat b3, GLfloat a3) {

  // If buffer is full, flush it
  if (vboDataIndex + 3 >= vboObjCapacity) R2D_GLES_FlushBuffers();

  // Set the triangle data into a formatted array
  GLfloat vertices[24] =
    { x1, y1, r1, g1, b1, a1, 0, 0,
      x2, y2, r2, g2, b2, a2, 0, 0,
      x3, y3, r3, g3, b3, a3, 0, 0 };

  // Copy the vertex data into the current position of the buffer
  memcpy(vboDataCurrent, vertices, sizeof(vertices));

  // Increment the buffer object index and the vertex data pointer for next use
  verticesTextureIds[vboDataIndex] = verticesTextureIds[vboDataIndex + 1] = verticesTextureIds[vboDataIndex + 2] = 0;
  vboDataIndex += 3;
  vboDataCurrent = (GLfloat *)((char *)vboDataCurrent + (sizeof(GLfloat) * 24));
}


/*
 * Draw a texture (New method with vertices pre-calculated)
 */
void R2D_GLES_DrawTexture(GLfloat coordinates[], GLfloat texture_coordinates[], GLfloat color[], int texture_id) {
  // If buffer is full, flush it
  if (vboDataIndex + 6 >= vboObjCapacity) R2D_GLES_FlushBuffers();

  // There are 6 vertices for a square as we are rendering two Triangles to make up our square:
  // Triangle one: Top left, Top right, Bottom right
  // Triangle two: Bottom right, Bottom left, Top left
  GLfloat vertices[48] = {
    coordinates[0], coordinates[1], color[0], color[1], color[2], color[3], texture_coordinates[0], texture_coordinates[1],
    coordinates[2], coordinates[3], color[0], color[1], color[2], color[3], texture_coordinates[2], texture_coordinates[3],
    coordinates[4], coordinates[5], color[0], color[1], color[2], color[3], texture_coordinates[4], texture_coordinates[5],
    coordinates[4], coordinates[5], color[0], color[1], color[2], color[3], texture_coordinates[4], texture_coordinates[5],
    coordinates[6], coordinates[7], color[0], color[1], color[2], color[3], texture_coordinates[6], texture_coordinates[7],
    coordinates[0], coordinates[1], color[0], color[1], color[2], color[3], texture_coordinates[0], texture_coordinates[1],
  };

  // Copy the vertex data into the current position of the buffer
  memcpy(vboDataCurrent, vertices, sizeof(vertices));

  verticesTextureIds[vboDataIndex] = verticesTextureIds[vboDataIndex + 1] = verticesTextureIds[vboDataIndex + 2] = verticesTextureIds[vboDataIndex + 3] = verticesTextureIds[vboDataIndex + 4] = verticesTextureIds[vboDataIndex + 5] = texture_id;
  vboDataIndex += 6;
  vboDataCurrent = (GLfloat *)((char *)vboDataCurrent + (sizeof(GLfloat) * 48));
}


#endif
