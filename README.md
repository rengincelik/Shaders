# Unity URP Shader Library

A collection of custom physically-based shaders for Unity's Universal Render Pipeline (URP), featuring advanced material properties and a comprehensive visualization system.

## 📋 Table of Contents
- [Overview](#-overview)
- [Requirements](#-requirements)
- [Shaders](#-shaders)
  - [Water Surface Shader](#1-water-surface-shader)
  - [Advanced Surface Shader](#2-advanced-surface-shader)
  - [Silk Shader](#3-silk-shader)
  - [Velvet Shader](#4-velvet-shader)
- [Gallery System](#-gallery-system)
  - [GalleryMaker](#gallerymaker)
  - [ShaderPropertyGridAnalyzerGizmos](#shaderpropertygridanalyzergizmos)
  - [ObjectGalleryMaker](#objectgallerymaker)
  - [Gallery](#gallery)
- [Installation](#-installation)
- [Usage](#-usage)
- [Notes](#-notes)
- [License](#-license)

## 🎯 Overview

This project serves as a personal shader library and portfolio, showcasing various material implementations with physically-based rendering techniques. Each shader is designed to replicate real-world material behaviors with customizable properties for artistic control.

## ⚙️ Requirements

- **Unity Version**: Unity 6
- **Render Pipeline**: Universal Render Pipeline (URP)
- **Required Packages**:
  - ProBuilder (for mesh generation in gallery systems)
  - Universal RP package

## 🎨 Shaders

### 1. Water Surface Shader
**Path**: `BasicURP/WaterSurfaceShader`

A dynamic water surface shader with procedural wave generation and realistic lighting.

**Features**:
- Procedural noise-based wave animation
- Dual-layer wave system (big waves + noise variation)
- Depth-based color gradient (shallow to deep water)
- Fresnel reflections
- Specular highlights
- Real-time normal calculation for wave dynamics

**Key Properties**:
- `_ColorShallow` / `_ColorDeep`: Water color gradient
- `_BigWaveAmplitude` / `_BigWaveFrequency` / `_BigWaveSpeed`: Wave animation controls
- `_NoiseScale` / `_NoiseAmplitude`: Wave variation parameters
- `_Smoothness` / `_SpecularStrength` / `_ReflectionStrength`: Surface properties

**Note**: Requires high vertex count meshes for smooth wave deformation (recommended: 400+ vertices).

---

### 2. Advanced Surface Shader
**Path**: `BasicLit/AdvancedSurface`

A versatile surface shader with extensive control over glossiness, roughness, and material finish.

**Features**:
- Glossy/metallic workflow
- Procedural roughness with multi-layer noise
- Flat surface vs. curved surface roughness modes
- Matte effect control
- PBR-compliant lighting model
- Shadow support with intensity control

**Key Properties**:
- `_Metallic` / `_Smoothness` / `_SpecularPower`: PBR controls
- `_Roughness` / `_RoughnessEffect` / `_RoughnessIntensity`: Surface roughness
- `_FlatSurface`: Toggle between flat and organic roughness
- `_MatteEffect`: Diffuse softness control
- `_AmbientIntensity` / `_ShadowIntensity`: Lighting adjustments

---

### 3. Silk Shader
**Path**: `BasicURP/SilkShader`

A sophisticated fabric shader simulating silk's characteristic sheen and anisotropic highlights.

**Features**:
- Anisotropic GGX specular model
- Sheen layer with customizable tint
- Iridescence effect
- Micro-roughness variation
- Fresnel reflections
- Multi-light support

**Key Properties**:
- `_BaseColor` / `_SpecularColor`: Base material colors
- `_Anisotropy` / `_AnisotropyRotation`: Anisotropic reflection controls
- `_Sheen` / `_SheenTint`: Fabric sheen parameters
- `_IridescenceStrength`: Color shift intensity
- `_MicroRoughness`: Surface detail variation

---

### 4. Velvet Shader
**Path**: `BasicURP/VelvetShader`

A fabric shader designed to replicate velvet's soft, fuzzy appearance and subsurface scattering.

**Features**:
- Custom velvet BRDF with rim lighting
- Fuzz scatter simulation
- Anisotropic specular highlights
- Subsurface scattering approximation
- Micro-detail surface variation

**Key Properties**:
- `_BaseColor` / `_VelvetColor`: Material colors
- `_VelvetStrength` / `_VelvetPower`: Velvet rim effect
- `_FuzzScatter`: Edge fuzziness
- `_Anisotropy`: Directional highlights
- `_SubsurfaceScatter`: Light penetration simulation
- `_Smoothness` / `_Metallic`: Surface finish

## 🖼️ Gallery System

The project includes multiple gallery generation tools for shader visualization and comparison.

### GalleryMaker
**Purpose**: Generate a grid of objects showing property variations across multiple values.

**Features**:
- Automatic detection of shader properties (Float/Range types)
- Two-tier percentage system (main columns × sub columns)
- Color property override support
- Scene gizmos with property labels

**Use Case**: Ideal for analyzing how individual shader properties affect the final look across a range of values.

---

### ShaderPropertyGridAnalyzerGizmos
**Purpose**: Similar to GalleryMaker but with enhanced gizmo visualization.

**Features**:
- Property grid generation
- Visual labels in scene view
- Percentage-based property testing
- Shader name display

**Use Case**: Best for editor-time analysis and documentation of shader behavior.

---

### ObjectGalleryMaker
**Purpose**: Generate meshes with varying vertex densities using ProBuilder.

**Features**:
- Procedural plane generation
- Configurable vertex counts (e.g., 4, 25, 100, 400, 900)
- Automatic subdivision calculation
- Vertex count display in scene view

**Use Case**: Essential for testing the Water Surface Shader, which requires high vertex density for smooth wave animations.

---

### Gallery
**Purpose**: Generate comprehensive combinations of shaders, prefabs, and colors.

**Features**:
- Multi-shader support
- Multiple prefab testing
- Color variant generation
- Organized hierarchy (Shader → Prefab → Color)

**Use Case**: Perfect for comparing multiple shaders across different mesh types and color variations simultaneously.

## 📦 Installation

1. Clone or download this repository
2. Open your Unity 6 project with URP configured
3. Import the shader files into your `Assets/Shaders` folder
4. Import the gallery scripts into your `Assets/Scripts` folder
5. Install ProBuilder via Package Manager (Window → Package Manager → ProBuilder)

## 🚀 Usage

### Using Shaders
1. Create a new material
2. Select the desired shader from the shader dropdown menu
3. Adjust properties in the Material Inspector
4. Apply the material to your mesh

### Using Gallery Systems

#### Basic Gallery Setup
1. Create an empty GameObject in your scene
2. Add the desired gallery script component
3. Assign the base material with your shader
4. Assign a display prefab (sphere, cube, etc.)
5. Check "Build In Editor" to generate the gallery

#### For Water Surface
1. Use `ObjectGalleryMaker` to generate high-poly planes
2. Set target vertex counts (e.g., `[25, 100, 400, 900]`)
3. Build the gallery
4. Apply Water Surface Shader material to the generated planes

#### Property Analysis
1. Use `GalleryMaker` or `ShaderPropertyGridAnalyzerGizmos`
2. Configure main and sub column percentages
3. Optionally override color properties
4. Build and analyze property variations

## 📝 Notes

- All shaders include proper Shadow Caster and Depth passes for URP
- Materials are generated procedurally by gallery systems
- Scene gizmos display property names and values for easy reference
- Water shader performs vertex displacement, requiring appropriate mesh density

## 📄 License

This project is developed for personal use, portfolio, and learning purposes.

---

**Author**: Rengin Çelik
**Unity Version**: Unity 6  
**Render Pipeline**: Universal Render Pipeline (URP)  
**Year**: 2025
