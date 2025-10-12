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

    private float[] valueSteps = new float[] { 0f, 0.25f, 0.5f, 0.75f, 1f };
    // Diğer property'lerin alacağı değerler (0%, 50%, 100%)
    private float[] scenarioSteps = new float[] { 0f, 0.5f, 1f };

    // Konumlandırma değişkenleri
    private float rowSpacing = 3f;      // Satırlar arası dikey mesafe
    private float subSpacing = 1.2f;    // Alt grup objeleri arası yatay mesafe (daha az)
    [SerializeField] private float groupGap = 1.0f; // Ana % grupları arasına eklenecek ekstra boşluk

    private float labelOffsetX = 1.5f;
    private float labelOffsetY = 1.5f;

#if UNITY_EDITOR
    void OnValidate()
    {
        if (baseMaterial != null)
        {
            UpdateColorPropertyList();
        }

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
                colorProperties.Add(new ColorProperty { propertyName = propName, color = baseMaterial.GetColor(propName) });
            }
        }
        colorProperties.RemoveAll(cp => !shaderColorProps.Contains(cp.propertyName));
    }

    void BuildGrid()
    {
        if (baseMaterial == null || displayPrefab == null) return;

        // Mevcut child'ları temizle
        for (int i = transform.childCount - 1; i >= 0; i--)
            DestroyImmediate(transform.GetChild(i).gameObject);

        Shader shader = baseMaterial.shader;
        List<string> numericProps = new List<string>();
        for (int i = 0; i < shader.GetPropertyCount(); i++)
        {
            var propType = shader.GetPropertyType(i);
            if (propType == UnityEngine.Rendering.ShaderPropertyType.Float ||
                propType == UnityEngine.Rendering.ShaderPropertyType.Range)
            {
                numericProps.Add(shader.GetPropertyName(i));
            }
        }

        int N = numericProps.Count;
        int V = valueSteps.Length;
        int S = scenarioSteps.Length;

        // Bir ana gruptaki (Örn: 50% Grubu) objelerin toplam genişliği
        float groupWidth = S * subSpacing;

        // ----------------------------------------------------
        // 1. Dış Döngü (Row): Ana Property (Test Edilen)
        // ----------------------------------------------------
        for (int row = 0; row < N; row++)
        {
            string mainPropName = numericProps[row]; // Test edilen property

            GameObject rowParent = new GameObject(mainPropName + "_Test_Row");
            rowParent.transform.SetParent(transform);
            rowParent.transform.localPosition = new Vector3(0, row * rowSpacing, 0);

            // ----------------------------------------------------
            // 2. Orta Döngü (Value): Ana Değer (0%, 25%, 50%...)
            // ----------------------------------------------------
            for (int valCol = 0; valCol < V; valCol++)
            {
                float mainVal = valueSteps[valCol];

                // Grup Başlangıç Konumu: Önceki grupların genişliği + gruplar arası boşluk
                float groupStartOffset = valCol * (groupWidth + groupGap);

                // ----------------------------------------------------
                // 3. İç Döngü (Scenario): Diğer Property Senaryosu (0%, 50%, 100%)
                // ----------------------------------------------------
                for (int scenarioCol = 0; scenarioCol < S; scenarioCol++)
                {
                    float scenarioVal = scenarioSteps[scenarioCol];

                    // Objenin X Konumu: Grup başlangıcı + alt grup içindeki ofset
                    float totalOffsetX = groupStartOffset + (scenarioCol * subSpacing);

                    GameObject instance = PrefabUtility.InstantiatePrefab(displayPrefab, rowParent.transform) as GameObject;
                    if (instance == null) continue;

                    instance.name = $"{mainPropName}_{mainVal * 100}%_Other_{scenarioVal * 100}%";
                    instance.transform.localPosition = new Vector3(totalOffsetX, 0, 0);

                    Renderer rend = instance.GetComponent<Renderer>();
                    if (rend != null)
                    {
                        Material matVariant = new Material(baseMaterial);
                        matVariant.name = instance.name;

                        // Color property'leri ata
                        foreach (var colorProp in colorProperties)
                        {
                            matVariant.SetColor(colorProp.propertyName, colorProp.color);
                        }

                        // TÜM NUMERİK PROPERTY'LERİ AYARLA
                        foreach (string propName in numericProps)
                        {
                            if (propName == mainPropName)
                            {
                                // A) Test edilen property'ye ana değeri ata
                                matVariant.SetFloat(propName, mainVal);
                            }
                            else
                            {
                                // B) Diğer property'lere senaryo değerini ata
                                matVariant.SetFloat(propName, scenarioVal);
                            }
                        }

                        rend.sharedMaterial = matVariant;
                    }
                }
            }
        }
    }

    // Gizmos ile yazıları çiz (YENİ YAPILANDIRILMIŞ)
    void OnDrawGizmos()
    {
        if (baseMaterial == null) return;

        Shader shader = baseMaterial.shader;
        List<string> numericProps = new List<string>();
        for (int i = 0; i < shader.GetPropertyCount(); i++)
        {
            var propType = shader.GetPropertyType(i);
            if (propType == UnityEngine.Rendering.ShaderPropertyType.Float ||
                propType == UnityEngine.Rendering.ShaderPropertyType.Range)
                numericProps.Add(shader.GetPropertyName(i));
        }

        int N = numericProps.Count;
        int V = valueSteps.Length;
        int S = scenarioSteps.Length;
        float groupWidth = S * subSpacing;

        // Stiller
        GUIStyle rowLabelStyle = new GUIStyle(GUI.skin.label);
        rowLabelStyle.fontSize = 16;
        rowLabelStyle.fontStyle = FontStyle.Bold;
        rowLabelStyle.normal.textColor = Color.white;
        rowLabelStyle.alignment = TextAnchor.MiddleRight;

        GUIStyle mainValueStyle = new GUIStyle(GUI.skin.label);
        mainValueStyle.fontSize = 14;
        mainValueStyle.fontStyle = FontStyle.Bold;
        mainValueStyle.normal.textColor = Color.yellow;
        mainValueStyle.alignment = TextAnchor.MiddleCenter;

        GUIStyle scenarioStyle = new GUIStyle(GUI.skin.label);
        scenarioStyle.fontSize = 10;
        scenarioStyle.normal.textColor = Color.cyan;
        scenarioStyle.alignment = TextAnchor.LowerCenter;

        // ----------------------------------------------------
        // 1. Satır Başlıkları (Y Ekseni)
        // ----------------------------------------------------
        for (int row = 0; row < N; row++)
        {
            string propName = numericProps[row];
            Vector3 labelPos = transform.position + new Vector3(-labelOffsetX, row * rowSpacing, 0);
            Handles.Label(labelPos, propName, rowLabelStyle);
        }

        // ----------------------------------------------------
        // 2. Sütun Başlıkları (X Ekseni)
        // ----------------------------------------------------
        for (int valCol = 0; valCol < V; valCol++)
        {
            float mainVal = valueSteps[valCol];
            float groupStartOffset = valCol * (groupWidth + groupGap);

            // A) Ana Değer Etiketi (Örn: "50%") - En Üstte
            float mainLabelX = groupStartOffset + (groupWidth / 2f) - (subSpacing / 2f);
            Vector3 mainLabelPos = transform.position + new Vector3(mainLabelX, N * rowSpacing + labelOffsetY, 0);
            Handles.Label(mainLabelPos, $"{mainVal * 100:F0}%", mainValueStyle);

            // B) Senaryo Etiketleri (Örn: "0%", "50%", "100%") - Objelerin Üzerinde
            for (int scenarioCol = 0; scenarioCol < S; scenarioCol++)
            {
                float scenarioVal = scenarioSteps[scenarioCol];

                float totalOffsetX = groupStartOffset + (scenarioCol * subSpacing);
                Vector3 subLabelPos = transform.position + new Vector3(totalOffsetX, N * rowSpacing + 0.5f, 0);

                Handles.Label(subLabelPos, $"{scenarioVal * 100:F0}%", scenarioStyle);
            }
        }
    }
#endif
}

// using UnityEngine;
// #if UNITY_EDITOR
// using UnityEditor;
// #endif
// using System.Collections.Generic;

// [ExecuteInEditMode]
// public class ShaderPropertyGridAnalyzerGizmos : MonoBehaviour
// {
//     [SerializeField] private Material baseMaterial;
//     [SerializeField] private GameObject displayPrefab;
//     [SerializeField] private bool buildInEditor;
//     [SerializeField][Range(0, 100)] int value;

//     [Header("Color Properties")]
//     [SerializeField] private List<ColorProperty> colorProperties = new List<ColorProperty>();

//     [System.Serializable]
//     public class ColorProperty
//     {
//         public string propertyName;
//         public Color color = Color.white;
//     }

//     private float[] valueSteps = new float[] { 0f, 0.25f, 0.5f, 0.75f, 1f };
//     private float rowSpacing = 3f;
//     private float colSpacing = 2f;
//     private float labelOffsetX = 1.5f; // Satır etiketleri için X offset (anchor sağda olduğu için daha yakın olabilir)
//     private float labelOffsetY = 1.5f; // Sütun etiketleri için Y offset

// #if UNITY_EDITOR
//     void OnValidate()
//     {
//         // Shader değiştiğinde color property listesini güncelle
//         if (baseMaterial != null)
//         {
//             UpdateColorPropertyList();
//         }

//         if (buildInEditor)
//         {
//             buildInEditor = false;
//             EditorApplication.delayCall += BuildGrid;
//         }
//     }

//     void UpdateColorPropertyList()
//     {
//         if (baseMaterial == null) return;

//         Shader shader = baseMaterial.shader;
//         int propCount = shader.GetPropertyCount();

//         // Mevcut color property'leri bul
//         List<string> shaderColorProps = new List<string>();
//         for (int i = 0; i < propCount; i++)
//         {
//             var propType = shader.GetPropertyType(i);
//             if (propType == UnityEngine.Rendering.ShaderPropertyType.Color)
//             {
//                 shaderColorProps.Add(shader.GetPropertyName(i));
//             }
//         }

//         // Mevcut listeyi güncelle (var olanları koru, yenileri ekle)
//         foreach (string propName in shaderColorProps)
//         {
//             if (!colorProperties.Exists(cp => cp.propertyName == propName))
//             {
//                 colorProperties.Add(new ColorProperty
//                 {
//                     propertyName = propName,
//                     color = baseMaterial.GetColor(propName)
//                 });
//             }
//         }

//         // Shader'da olmayan property'leri temizle
//         colorProperties.RemoveAll(cp => !shaderColorProps.Contains(cp.propertyName));
//     }

// // Ek bir senaryo dizisi tanımlayalım
// private float[] scenarioSteps = new float[] { 0f,0.25f, 0.5f,0.75f, 1f }; // 0%, 50%, 100%
// private float scenarioSpacing = 1.0f; // Alt gruplar arası daha küçük boşluk

//     // rowSpacing ve colSpacing değerlerini koruyabiliriz.

//     void BuildGrid()
//     {
//         if (baseMaterial == null || displayPrefab == null)
//             return;

//         // Mevcut child'ları temizle
//         for (int i = transform.childCount - 1; i >= 0; i--)
//             DestroyImmediate(transform.GetChild(i).gameObject);

//         Shader shader = baseMaterial.shader;
//         List<string> numericProps = new List<string>();
//         // Property'leri topla
//         for (int i = 0; i < shader.GetPropertyCount(); i++)
//         {
//             var propType = shader.GetPropertyType(i);
//             if (propType == UnityEngine.Rendering.ShaderPropertyType.Float ||
//                 propType == UnityEngine.Rendering.ShaderPropertyType.Range)
//             {
//                 numericProps.Add(shader.GetPropertyName(i));
//             }
//         }

//         int N = numericProps.Count;
//         int V = valueSteps.Length; // 5 adım
//         int S = scenarioSteps.Length; // 5 senaryo

//         // Bir ana grup için gerekli toplam X ofseti (5 * 5 = 25 obje + boşluk)
//         float majorGroupSpacing = (V * S * colSpacing) + colSpacing;

//         // ----------------------------------------------------
//         // 1. Dış Döngü (Y Ekseninde): Ana Property (Test Edilen)
//         // ----------------------------------------------------
//         for (int row = 0; row < N; row++)
//         {
//             string mainPropName = numericProps[row]; // Örn: "_Smoothness"

//             // Ana Parent (Satır)
//             GameObject rowParent = new GameObject(mainPropName + "_Test_Row");
//             rowParent.transform.SetParent(transform);
//             rowParent.transform.localPosition = new Vector3(0, row * rowSpacing, 0);

//             // ----------------------------------------------------
//             // 2. Orta Döngü (X Ekseninde): Ana Değer (0%, 25%, 50%...)
//             // ----------------------------------------------------
//             for (int valCol = 0; valCol < V; valCol++)
//             {
//                 float mainVal = valueSteps[valCol]; // Örn: 0.5

//                 // ----------------------------------------------------
//                 // 3. İç Döngü (X Ekseninde): Diğer Property Senaryosu (0%, 50%, 100%)
//                 // ----------------------------------------------------
//                 for (int scenarioCol = 0; scenarioCol < S; scenarioCol++)
//                 {
//                     float scenarioVal = scenarioSteps[scenarioCol]; // Örn: 1.0

//                     // Objenin X Konumunu Hesapla: (Ana Değer Grubu Başlangıcı) + (Senaryo İçi Offset)
//                     float totalOffsetX = (valCol * (S * colSpacing)) + (scenarioCol * colSpacing);

//                     GameObject instance = PrefabUtility.InstantiatePrefab(displayPrefab, rowParent.transform) as GameObject;
//                     if (instance == null) continue;

//                     instance.name = $"{mainPropName}_{mainVal * 100}%_Other_{scenarioVal * 100}%";
//                     instance.transform.localPosition = new Vector3(totalOffsetX, 0, 0);

//                     Renderer rend = instance.GetComponent<Renderer>();
//                     if (rend != null)
//                     {
//                         Material matVariant = new Material(baseMaterial);
//                         matVariant.name = instance.name;

//                         // Color property'leri ata
//                         foreach (var colorProp in colorProperties)
//                         {
//                             matVariant.SetColor(colorProp.propertyName, colorProp.color);
//                         }

//                         // TÜM NUMERİK PROPERTY'LERİ AYARLA
//                         foreach (string propName in numericProps)
//                         {
//                             if (propName == mainPropName)
//                             {
//                                 // A) Ana Property'yi (Test Edileni) Orta Döngü Değeriyle ayarla
//                                 matVariant.SetFloat(propName, mainVal);
//                             }
//                             else
//                             {
//                                 // B) Diğer Property'leri İç Döngü Senaryo Değeriyle ayarla
//                                 matVariant.SetFloat(propName, scenarioVal);
//                             }
//                         }

//                         rend.sharedMaterial = matVariant;
//                     }
//                 }
//             }
//         }


//     }

//     // Gizmos ile yazıları çiz
//     void OnDrawGizmos()
//     {
//         if (baseMaterial == null) return;

//         Shader shader = baseMaterial.shader;
//         int propCount = shader.GetPropertyCount();

//         List<string> numericProps = new List<string>();
//         for (int i = 0; i < propCount; i++)
//         {
//             var propType = shader.GetPropertyType(i);
//             if (propType == UnityEngine.Rendering.ShaderPropertyType.Float ||
//                 propType == UnityEngine.Rendering.ShaderPropertyType.Range)
//                 numericProps.Add(shader.GetPropertyName(i));
//         }

//         // Sabit font boyutu için GUIStyle
//         GUIStyle labelStyle = new GUIStyle(GUI.skin.label);
//         labelStyle.fontSize = 16;
//         labelStyle.fontStyle = FontStyle.Bold;
//         labelStyle.normal.textColor = Color.white;
//         labelStyle.alignment = TextAnchor.MiddleRight; // Sağa hizala

//         GUIStyle percentStyle = new GUIStyle(GUI.skin.label);
//         percentStyle.fontSize = 14;
//         percentStyle.normal.textColor = Color.yellow;
//         percentStyle.alignment = TextAnchor.MiddleCenter;

//         // Satır başları - Property adları (solda, sağa hizalı)
//         for (int row = 0; row < numericProps.Count; row++)
//         {
//             string propName = numericProps[row];
//             Vector3 labelPos = transform.position + new Vector3(-labelOffsetX, row * rowSpacing, 0);
//             Handles.Label(labelPos, propName, labelStyle);
//         }

//         // Sütun başları - Yüzde değerleri (üstte)
//         for (int col = 0; col < valueSteps.Length; col++)
//         {
//             float val = valueSteps[col];
//             Vector3 colPos = transform.position + new Vector3(col * colSpacing*3f+1f, -labelOffsetY, 0);
//             Handles.Label(colPos, $"{val * 100:F0}%", percentStyle);
//         }
//     }
// #endif
// }
