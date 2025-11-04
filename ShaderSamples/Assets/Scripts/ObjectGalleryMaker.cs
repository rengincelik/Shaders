using UnityEngine;
using UnityEngine.ProBuilder;
using UnityEngine.ProBuilder.MeshOperations;
#if UNITY_EDITOR
using UnityEditor;
#endif

[ExecuteInEditMode]
public class ProBuilderVertexComparison : MonoBehaviour
{
    [SerializeField] private Material baseMaterial;
    [SerializeField] private bool buildInEditor;

    [Header("Vertex Count Settings")]
    [Tooltip("İstediğin vertex sayıları (yaklaşık). Örnek: 4, 25, 100, 400")]
    [SerializeField] private int[] targetVertexCounts = { 4, 25, 100, 400, 900 };

    [SerializeField] private float spacing = 2.5f;
    [SerializeField] private float planeSize = 1f;

    [Header("Debug")]
    [SerializeField] private bool showVertexCount = true;

#if UNITY_EDITOR
    void OnValidate()
    {
        if (buildInEditor)
        {
            buildInEditor = false;
            EditorApplication.delayCall += BuildPlanes;
        }
    }

    void BuildPlanes()
    {
        if (baseMaterial == null)
        {
            Debug.LogWarning("Base material atanmadı.");
            return;
        }

        // Eski child objeleri temizle
        for (int i = transform.childCount - 1; i >= 0; i--)
            DestroyImmediate(transform.GetChild(i).gameObject);

        for (int i = 0; i < targetVertexCounts.Length; i++)
        {
            int targetVerts = targetVertexCounts[i];

            // Vertex sayısından segment sayısını hesapla
            // Bir plane'de vertex sayısı = (segments+1)^2
            // Yani segments = sqrt(vertexCount) - 1
            int segments = Mathf.Max(1, Mathf.RoundToInt(Mathf.Sqrt(targetVerts)) - 1);

            // ProBuilder plane oluştur
            ProBuilderMesh mesh = ShapeGenerator.GeneratePlane(
                PivotLocation.Center,
                planeSize,
                planeSize,
                segments,
                segments,
                Axis.Up
            );

            GameObject plane = mesh.gameObject;
            plane.transform.SetParent(transform);
            plane.transform.localPosition = new Vector3(i * spacing, 0f, 0f);
            plane.transform.localRotation = Quaternion.identity;
            plane.transform.localScale = Vector3.one;

            int actualVertCount = mesh.vertexCount;
            int faceCount = mesh.faceCount;
            plane.name = $"Plane_V{actualVertCount}_F{faceCount}";

            Renderer rend = plane.GetComponent<Renderer>();
            if (rend != null)
                rend.sharedMaterial = baseMaterial;

            // Mesh'i güncelle
            mesh.ToMesh();
            mesh.Refresh();

            Debug.Log($"Target: {targetVerts} verts → Actual: {actualVertCount} verts (segments: {segments}x{segments})");
        }

        Debug.Log($"Toplam {targetVertexCounts.Length} plane oluşturuldu.");
    }

    void OnDrawGizmos()
    {
#if UNITY_EDITOR
        if (targetVertexCounts == null || targetVertexCounts.Length == 0) return;

        GUIStyle vertStyle = new GUIStyle(GUI.skin.label)
        {
            fontSize = 12,
            fontStyle = FontStyle.Bold,
            normal = { textColor = Color.cyan },
            alignment = TextAnchor.MiddleCenter
        };

        for (int i = 0; i < targetVertexCounts.Length; i++)
        {
            int targetVerts = targetVertexCounts[i];
            int segments = Mathf.Max(1, Mathf.RoundToInt(Mathf.Sqrt(targetVerts)) - 1);
            int actualVerts = (segments + 1) * (segments + 1);

            Vector3 pos = transform.position + new Vector3(i * spacing, 0f, 0f);

            if (showVertexCount)
                Handles.Label(pos + Vector3.up * 0.5f, $"{actualVerts} verts", vertStyle);
        }
#endif
    }
#endif
}
