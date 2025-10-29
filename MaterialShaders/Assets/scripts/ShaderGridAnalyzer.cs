using UnityEngine;
using System.Collections.Generic;

public class ShaderPropertyGridDisplay : MonoBehaviour
{
    [SerializeField] private Material baseMaterial;
    [SerializeField] private GameObject displayPrefab; // Cube veya benzeri
    [SerializeField] private GameObject textPrefab; // TextMesh prefab

    [Header("Settings")]
    public float rowSpacing = 3f;
    public float subSpacing = 1.5f;
    public float groupSpacing = 2.5f;
    public float labelOffsetX = 1.5f;
    public float labelOffsetY = 1.5f;

    private List<GameObject> spawnedObjects = new List<GameObject>();

    void Start()
    {
        BuildGrid();
    }

    void BuildGrid()
    {
        if (baseMaterial == null || displayPrefab == null || textPrefab == null) return;

        // Mevcutları temizle
        foreach (var obj in spawnedObjects)
            Destroy(obj);
        spawnedObjects.Clear();

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

        for (int row = 0; row < numericProps.Count; row++)
        {
            string propName = numericProps[row];

            // Label
            GameObject labelObj = Instantiate(textPrefab, transform);
            labelObj.transform.localPosition = new Vector3(-labelOffsetX, row * rowSpacing, 0);
            TextMesh labelMesh = labelObj.GetComponent<TextMesh>();
            if (labelMesh != null) labelMesh.text = propName;
            spawnedObjects.Add(labelObj);

            // Display prefab
            for (int i = 0; i < 5; i++) // main columns örnek
            {
                for (int j = 0; j < 5; j++) // sub columns örnek
                {
                    GameObject instance = Instantiate(displayPrefab, transform);
                    instance.transform.localPosition = new Vector3(i * (groupSpacing + 5 * subSpacing) + j * subSpacing, row * rowSpacing, 0);

                    Renderer rend = instance.GetComponent<Renderer>();
                    if (rend != null)
                    {
                        Material mat = new Material(baseMaterial);
                        mat.SetFloat(propName, j / 4f); // sub
                        foreach (var otherProp in numericProps)
                            if (otherProp != propName) mat.SetFloat(otherProp, i / 4f); // main
                        rend.sharedMaterial = mat;
                    }

                    spawnedObjects.Add(instance);
                }
            }
        }
    }
}
