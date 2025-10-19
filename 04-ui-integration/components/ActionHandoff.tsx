/**
 * VaultMesh Q Business - Action Handoff Component
 *
 * Renders action buttons from the catalog and handles invocation.
 * Displays results inline with proper error handling.
 *
 * Usage:
 * <ActionHandoff
 *   selectedUris={["s3://bucket/doc.md"]}
 *   user={{ id: "alice@vaultmesh.io", groups: ["VaultMesh-Engineering"] }}
 * />
 */

"use client";

import { useEffect, useState } from "react";

interface ActionEntry {
  id: string;
  name: string;
  description?: string;
  safetyTier?: string;
  invocation?: {
    mode?: string;
    handoffText?: string;
  };
}

interface User {
  id?: string;
  groups?: string[];
}

interface ActionHandoffProps {
  selectedUris: string[];
  user?: User;
  onResult?: (actionId: string, result: any) => void;
  onError?: (actionId: string, error: string) => void;
}

export default function ActionHandoff({
  selectedUris,
  user,
  onResult,
  onError,
}: ActionHandoffProps) {
  const [actions, setActions] = useState<ActionEntry[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  const [result, setResult] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // Load catalog on mount
  useEffect(() => {
    loadCatalog();
  }, []);

  async function loadCatalog() {
    try {
      const res = await fetch("/api/actions/catalog");
      const data = await res.json();
      setActions(data.catalog || []);
    } catch (err: any) {
      console.error("Failed to load catalog:", err);
      setError("Failed to load actions catalog");
    } finally {
      setLoading(false);
    }
  }

  async function runAction(actionId: string) {
    setBusy(actionId);
    setError(null);
    setResult(null);

    try {
      const body = {
        actionId,
        user: user ?? {},
        params: buildParams(actionId, selectedUris),
      };

      const res = await fetch("/api/actions/invoke", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      const json = await res.json();

      if (res.ok) {
        // Parse body if it's a Lambda response wrapper
        const actionResult = json.body || json;
        setResult(actionResult);
        onResult?.(actionId, actionResult);
      } else {
        const errorMsg = json.error || `Action failed with status ${res.status}`;
        setError(errorMsg);
        onError?.(actionId, errorMsg);
      }
    } catch (err: any) {
      const errorMsg = err.message || "Network error";
      setError(errorMsg);
      onError?.(actionId, errorMsg);
    } finally {
      setBusy(null);
    }
  }

  /**
   * Build params for each action based on selected URIs
   */
  function buildParams(
    actionId: string,
    uris: string[]
  ): Record<string, unknown> {
    switch (actionId) {
      case "summarize-docs":
        return {
          documentUris: uris,
          audience: user?.groups?.includes("VaultMesh-Delivery")
            ? "delivery"
            : "engineering",
        };

      case "generate-faq":
        return {
          folderPrefix: commonPrefix(uris),
          maxQuestions: 12,
        };

      case "draft-change-note":
        return {
          baselineUri: uris[0] || "",
          updatedUri: uris[1] || uris[0] || "",
          changeWindow: new Date().toISOString().slice(0, 7), // YYYY-MM
        };

      case "validate-schema":
        return {
          schemaUri: uris[0] || "",
          profile: "both",
        };

      case "create-jira-draft":
        return {
          projectKey: "VM",
          summary: "Draft ticket from Q Business",
          description: `Context: ${uris.join(", ")}`,
          labels: ["qbusiness", "automated"],
        };

      case "compliance-pack":
        return {
          sourceUris: uris,
          regime: "AI-Act",
        };

      default:
        return {};
    }
  }

  /**
   * Extract common S3 prefix from URIs
   */
  function commonPrefix(uris: string[]): string {
    if (!uris.length) return "s3://vaultmesh-knowledge-base/";
    return uris[0].replace(/\/[^/]*$/, "/");
  }

  /**
   * Render result based on action type
   */
  function renderResult(actionId: string, data: any) {
    if (!data) return null;

    switch (actionId) {
      case "summarize-docs":
        return (
          <div className="prose prose-sm max-w-none">
            <div dangerouslySetInnerHTML={{ __html: markdownToHtml(data.summaryMarkdown) }} />
          </div>
        );

      case "generate-faq":
        return (
          <div className="prose prose-sm max-w-none">
            <div dangerouslySetInnerHTML={{ __html: markdownToHtml(data.faqMarkdown) }} />
          </div>
        );

      case "draft-change-note":
        return (
          <div className="prose prose-sm max-w-none">
            <div dangerouslySetInnerHTML={{ __html: markdownToHtml(data.changeMarkdown) }} />
          </div>
        );

      case "validate-schema":
        return (
          <pre className="text-sm bg-gray-50 p-4 rounded overflow-x-auto">
            {JSON.stringify(data.validationReport, null, 2)}
          </pre>
        );

      case "create-jira-draft":
        return (
          <div className="space-y-2">
            <p className="text-sm font-medium">Jira Ticket Draft:</p>
            <pre className="text-sm bg-gray-50 p-4 rounded overflow-x-auto">
              {JSON.stringify(data.jiraPayload, null, 2)}
            </pre>
          </div>
        );

      case "compliance-pack":
        return (
          <div className="space-y-2">
            <p className="text-sm">
              <strong>Package URI:</strong>{" "}
              <code className="text-xs bg-gray-100 px-1 rounded">
                {data.packageUri}
              </code>
            </p>
            <div className="prose prose-sm max-w-none">
              <div dangerouslySetInnerHTML={{ __html: markdownToHtml(data.coverMarkdown) }} />
            </div>
          </div>
        );

      default:
        return (
          <pre className="text-sm bg-gray-50 p-4 rounded overflow-x-auto">
            {JSON.stringify(data, null, 2)}
          </pre>
        );
    }
  }

  /**
   * Simple markdown to HTML conversion (replace with proper library in production)
   */
  function markdownToHtml(markdown: string | undefined): string {
    if (!markdown) return "";
    return markdown
      .replace(/^### (.*$)/gim, "<h3>$1</h3>")
      .replace(/^## (.*$)/gim, "<h2>$1</h2>")
      .replace(/^# (.*$)/gim, "<h1>$1</h1>")
      .replace(/\*\*(.*)\*\*/gim, "<strong>$1</strong>")
      .replace(/\*(.*)\*/gim, "<em>$1</em>")
      .replace(/^- (.*$)/gim, "<li>$1</li>")
      .replace(/\n/gim, "<br/>");
  }

  if (loading) {
    return (
      <div className="flex items-center space-x-2 text-sm text-gray-500">
        <div className="animate-spin h-4 w-4 border-2 border-indigo-600 border-t-transparent rounded-full" />
        <span>Loading actions...</span>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Action Buttons */}
      <div className="flex flex-wrap gap-2">
        {actions.map((action) => (
          <button
            key={action.id}
            disabled={busy === action.id || !selectedUris.length}
            onClick={() => runAction(action.id)}
            className={`
              rounded-md px-4 py-2 text-sm font-medium transition-colors
              ${
                action.safetyTier === "GREEN"
                  ? "bg-green-600 hover:bg-green-700"
                  : action.safetyTier === "YELLOW"
                  ? "bg-yellow-600 hover:bg-yellow-700"
                  : "bg-indigo-600 hover:bg-indigo-700"
              }
              text-white
              disabled:opacity-50 disabled:cursor-not-allowed
            `}
            title={action.description}
          >
            {busy === action.id ? (
              <span className="flex items-center space-x-2">
                <div className="animate-spin h-3 w-3 border-2 border-white border-t-transparent rounded-full" />
                <span>Running...</span>
              </span>
            ) : (
              action.invocation?.handoffText || action.name
            )}
          </button>
        ))}
      </div>

      {/* Status Messages */}
      {busy && (
        <p className="text-sm text-gray-600">
          Running <strong>{busy}</strong>...
        </p>
      )}

      {/* Error Display */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-md p-4">
          <p className="text-sm text-red-800 font-medium">Action Failed</p>
          <p className="text-sm text-red-600 mt-1">{error}</p>
        </div>
      )}

      {/* Result Display */}
      {result && busy === null && (
        <div className="bg-white border border-gray-200 rounded-md p-4">
          <p className="text-sm font-medium text-gray-700 mb-2">Result:</p>
          {renderResult(busy || "", result)}
        </div>
      )}

      {/* Help Text */}
      {!selectedUris.length && (
        <p className="text-sm text-gray-500">
          Select one or more documents to enable actions
        </p>
      )}
    </div>
  );
}
