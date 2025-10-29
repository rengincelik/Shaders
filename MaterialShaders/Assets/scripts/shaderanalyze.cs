using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif
using System.Collections.Generic;

[ExecuteInEditMode]
public class ShaderPropertyGridAnalyzerGizmos : MonoBehaviour
{
    [SerializeField] private Material baseMaterial;
    [SerializeField] private GameObject displayPrefab;
    [SerializeField] private bool buildInEditor;

    [Header("Color Properties")]
    [SerializeField] private List<ColorProperty> colorProperties = new List<ColorProperty>();

    [System.Serializable]
    public class ColorProperty
    {
        public string propertyName;
        public Color color = Color.white;
    }

    public float[] mainColumnPercentages = { 0f, 0.25f, 0.5f, 0.75f, 1f };
    public float[] subColumnPercentages = { 0f, 0.25f, 0.5f, 0.75f, 1f };

    public float rowSpacing = 3f;
    public float subSpacing = 1.5f;
    public float groupSpacing = 2.5f;
    public float labelOffsetX = 1.5f;
    public float labelOffsetY = 1.5f;

#if UNITY_EDITOR
    void OnValidate()
    {
        if (baseMaterial != null)
            UpdateColorPropertyList();

        if (buildInEditor)
        {
            buildInEditor = false;
            EditorApplication.delayCall += BuildGrid;
        }
    }

    void UpdateColorPropertyList()
    {
        if (baseMaterial == null) return;

        Shader shader = baseMaterial.shader;
        int propCount = shader.GetPropertyCount();

        List<string> shaderColorProps = new List<string>();
        for (int i = 0; i < propCount; i++)
        {
            if (shader.GetPropertyType(i) == UnityEngine.Rendering.ShaderPropertyType.Color)
                shaderColorProps.Add(shader.GetPropertyName(i));
        }

        foreach (string propName in shaderColorProps)
        {
            if (!colorProperties.Exists(cp => cp.propertyName == propName))
            {
                colorProperties.Add(new ColorProperty
                {
                    propertyName = propName,
                    color = baseMaterial.GetColor(propName)
                });
            }
        }

        colorProperties.RemoveAll(cp => !shaderColorProps.Contains(cp.propertyName));
    }

    void BuildGrid()
    {
        if (baseMaterial == null || displayPrefab == null)
            return;

        // Mevcut child'ları temizle
        for (int i = transform.childCount - 1; i >= 0; i--)
            DestroyImmediate(transform.GetChild(i).gameObject);

        Shader shader = baseMaterial.shader;
        int propCount = shader.GetPropertyCount();

        List<string> numericProps = new List<string>();
        for (int i = 0; i < propCount; i++)
        {
            var type = shader.GetPropertyType(i);
            if (type == UnityEngine.Rendering.ShaderPropertyType.Float ||
                type == UnityEngine.Rendering.ShaderPropertyType.Range)
                numericProps.Add(shader.GetPropertyName(i));
        }

        for (int row = 0; row < numericProps.Count; row++)
        {
            string propName = numericProps[row];

            GameObject propParent = new GameObject(propName + "_Parent");
            propParent.transform.SetParent(transform);
            propParent.transform.localPosition = new Vector3(0, row * rowSpacing, 0);

            // Ana sütun
            for (int i = 0; i < mainColumnPercentages.Length; i++)
            {
                float mainPer = mainColumnPercentages[i];
                GameObject columnParent = new GameObject($"{propName}_{mainPer * 100:F0}%");
                columnParent.transform.SetParent(propParent.transform);
                columnParent.transform.localPosition = new Vector3(i * (groupSpacing + subColumnPercentages.Length * subSpacing), 0, 0);

                // İç sütun
                for (int j = 0; j < subColumnPercentages.Length; j++)
                {
                    float subPer = subColumnPercentages[j];
                    GameObject instance = PrefabUtility.InstantiatePrefab(displayPrefab, columnParent.transform) as GameObject;
                    if (instance == null) continue;

                    instance.name = $"{propName}_{mainPer:F2}_{subPer:F2}";
                    instance.transform.localPosition = new Vector3(j * subSpacing, 0, 0);

                    Renderer rend = instance.GetComponent<Renderer>();
                    if (rend == null) continue;

                    Material material = new Material(baseMaterial);
                    material.SetFloat(propName, subPer);

                    foreach (var otherProp in numericProps)
                        if (otherProp != propName)
                            material.SetFloat(otherProp, mainPer);

                    foreach (var colorProp in colorProperties)
                        material.SetColor(colorProp.propertyName, colorProp.color);


                    rend.sharedMaterial = material;
                }
            }
        }
    }

    void OnDrawGizmos()
    {
        if (baseMaterial == null) return;

        Shader shader = baseMaterial.shader;
        int propCount = shader.GetPropertyCount();

        List<string> numericProps = new List<string>();
        for (int i = 0; i < propCount; i++)
        {
            var t = shader.GetPropertyType(i);
            if (t == UnityEngine.Rendering.ShaderPropertyType.Float ||
                t == UnityEngine.Rendering.ShaderPropertyType.Range)
                numericProps.Add(shader.GetPropertyName(i));
        }

        // Shader adı
        GUIStyle shaderNameStyle = new GUIStyle(GUI.skin.label)
        {
            fontSize = 22,
            fontStyle = FontStyle.Bold,
            normal = { textColor = Color.red },
            alignment = TextAnchor.UpperCenter
        };
        Vector3 shaderNamePos = transform.position + new Vector3((mainColumnPercentages.Length - 1) * (groupSpacing + subColumnPercentages.Length * subSpacing) / 2, -2f, 0);
        Handles.Label(shaderNamePos, shader.name, shaderNameStyle);

        GUIStyle labelStyle = new GUIStyle(GUI.skin.label)
        {
            fontSize = 20,
            fontStyle = FontStyle.Bold,
            normal = { textColor = Color.black },
            alignment = TextAnchor.MiddleRight
        };

        GUIStyle percentStyle = new GUIStyle(GUI.skin.label)
        {
            fontSize = 16,
            normal = { textColor = Color.blue },
            alignment = TextAnchor.MiddleCenter
        };

        for (int row = 0; row < numericProps.Count; row++)
        {
            string propName = numericProps[row];
            Vector3 labelPos = transform.position + new Vector3(-labelOffsetX, row * rowSpacing, 0);
            Handles.Label(labelPos, propName, labelStyle);
        }

        for (int col = 0; col < mainColumnPercentages.Length; col++)
        {
            float val = mainColumnPercentages[col];
            Vector3 colPos = transform.position + new Vector3(col * (groupSpacing + subColumnPercentages.Length * subSpacing), -labelOffsetY, 0);
            Handles.Label(colPos, $"{val * 100:F0}%", percentStyle);
        }
    }


#endif
}
