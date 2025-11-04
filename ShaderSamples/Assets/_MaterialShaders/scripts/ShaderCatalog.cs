using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

[ExecuteInEditMode]
public class ShaderPrefabGallery : MonoBehaviour
{
    [SerializeField] private GameObject prefab;         
    private Material baseMaterial;     
    [SerializeField] private bool buildInEditor;         
    
    [SerializeField] private Color[] colors = new Color[]
    {
        Color.red, Color.green, Color.blue, Color.yellow,
        Color.cyan, Color.magenta, Color.white, Color.black, Color.gray
    };

#if UNITY_EDITOR
    void OnValidate()
    {
        if (baseMaterial == null) { baseMaterial = GetComponent<Renderer>().material; }
        if (buildInEditor)
        {
            buildInEditor = false;
            EditorApplication.delayCall += BuildGallery;
        }
    }

    void BuildGallery()
    {
        if (prefab == null || baseMaterial == null)
        {
            Debug.LogWarning("Prefab veya baseMaterial atanmamış.");
            return;
        }

        // Mevcut child'ları temizle
        for (int i = transform.childCount - 1; i >= 0; i--)
            DestroyImmediate(transform.GetChild(i).gameObject);

        float spacing = 1.5f;

        for (int i = 0; i < colors.Length; i++)
        {
            Color color = colors[i];

            // Material Variant (Editor-only)
            Material variant = new Material(baseMaterial);
            variant.name = baseMaterial.name + "_Variant_" + i;
            variant.parent = baseMaterial;
            variant.SetColor("_BaseColor", color);

            GameObject instance = PrefabUtility.InstantiatePrefab(prefab, transform) as GameObject;
            if (instance == null) continue;

            instance.name = prefab.name + "_" + i;
            instance.transform.localPosition = new Vector3(i * spacing, 0, 0);

            Renderer rend = instance.GetComponent<Renderer>();
            if (rend != null)
                rend.sharedMaterial = variant;
        }

        Debug.Log("Shader prefab gallery oluşturuldu.");
    }
#endif
}

