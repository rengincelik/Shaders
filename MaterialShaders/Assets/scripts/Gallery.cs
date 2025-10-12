using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[ExecuteInEditMode]
public class Gallery : MonoBehaviour
{
    [SerializeField] GameObject[] prefabs;
    [SerializeField] Shader[] shaders;

    [SerializeField] bool buildInEditor = false;

    Color[] colors;

    void InitializeColors()
    {
        colors = new Color[]
        {
            Color.red,
            Color.green,
            Color.blue,
            Color.yellow,
            Color.cyan,
            Color.magenta,
            Color.white,
            Color.black,
            Color.gray
        };
    }

    void OnValidate()
    {
        if (buildInEditor)
        {
            buildInEditor = false;
            BuildGalleryInEditor();
        }
    }

    void BuildGalleryInEditor()
    {
        if (prefabs == null || prefabs.Length == 0 || shaders == null || shaders.Length == 0)
        {
            Debug.LogWarning("Prefabs veya shaders atanmadı.");
            return;
        }

        InitializeColors();

        // Eski çocukları temizle
        while (transform.childCount > 0)
            DestroyImmediate(transform.GetChild(0).gameObject);

        float shaderSpacing = 10f;
        float prefabSpacing = 3f;
        float colorSpacing = 1.5f;

        for (int s = 0; s < shaders.Length; s++)
        {
            Shader shader = shaders[s];
            if (shader == null) continue;

            GameObject shaderParent = new GameObject(shader.name + "_Group");
            shaderParent.transform.SetParent(transform, false);
            shaderParent.transform.localPosition = new Vector3(s * shaderSpacing, 0, 0);

            for (int p = 0; p < prefabs.Length; p++)
            {
                GameObject prefab = prefabs[p];
                if (prefab == null) continue;

                GameObject prefabGroup = new GameObject(prefab.name + "_Variants");
                prefabGroup.transform.SetParent(shaderParent.transform, false);
                prefabGroup.transform.localPosition = new Vector3(0, 0, p * prefabSpacing);

                for (int c = 0; c < colors.Length; c++)
                {
                    Color color = colors[c];
                    Material mat = new Material(shader);
                    mat.SetColor("_BaseColor", color);


                    GameObject instance = PrefabUtility.InstantiatePrefab(prefab, prefabGroup.transform) as GameObject;
                    if (instance == null)
                    {
                        Debug.LogError($"InstantiatePrefab başarısız: {prefab.name}");
                        continue;
                    }

                    instance.name = $"{prefab.name}_{color}";
                    instance.transform.localPosition = new Vector3(c * colorSpacing, 0, 0);

                    Renderer rend = instance.GetComponent<Renderer>();
                    if (rend != null)
                        rend.sharedMaterial = mat;


                }
            }
        }

        Debug.Log("Gallery oluşturuldu (Editor).");
    }
}
