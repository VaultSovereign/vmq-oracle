# Development Guidelines

## Code Quality Standards

### File Structure and Organization
- **Modular Architecture**: Separate concerns into distinct directories (01-foundation, 02-qbusiness, 03-lambdas, 04-ui-integration)
- **Configuration Management**: Use `.env` files for environment variables with `.env.example` templates
- **Build Artifacts**: Keep build outputs in dedicated directories (`.build/`, `logs/`)
- **Documentation Co-location**: Place README files and documentation alongside relevant code

### Naming Conventions
- **Kebab-case for directories**: `02-qbusiness`, `04-ui-integration`
- **Snake_case for Python**: `vmq_common.py`, `persona_helper.py`
- **camelCase for TypeScript/JavaScript**: `ActionHandoff.tsx`, `invoke-route.ts`
- **Descriptive function names**: `resolve_persona()`, `authorize_action()`, `load_catalog()`
- **Prefixed utilities**: `vmq-` prefix for Lambda functions, `_` prefix for private functions

### Error Handling Patterns
- **Graceful degradation**: Fall back to mock mode when AWS services unavailable
- **Structured logging**: Use JSON format for logs with consistent fields (event, action, user, latency_ms)
- **Error propagation**: Return error objects with consistent structure `{error: string, status?: number}`
- **Timeout handling**: Set reasonable timeouts (2.5s for OPA calls)

## Semantic Patterns

### AWS Integration Patterns
- **Boto3 client initialization**: Initialize clients at module level with try/catch for import errors
- **S3 caching pattern**: Implement TTL-based caching (5 minutes) for frequently accessed S3 objects
- **Lambda invocation contract**: Standardized payload structure with action, user, context, params
- **CloudWatch metrics**: Publish custom metrics for actions (ActionsInvoked, ActionLatency)

### Authentication and Authorization
- **Multi-group support**: Handle both single `group` and `groups` array in user objects
- **Persona resolution**: Map IAM Identity Center groups to application personas
- **Policy-based authorization**: Use OPA for complex authorization with fallback to static rules
- **Safety tiers**: Categorize actions as GREEN (safe), YELLOW (gated), RED (forbidden)

### React/TypeScript Patterns
- **Functional components**: Use function declarations with TypeScript interfaces
- **State management**: Use useState hooks with proper typing
- **Error boundaries**: Implement error states with user-friendly messages
- **Loading states**: Show loading indicators during async operations
- **Conditional rendering**: Use ternary operators and logical AND for conditional UI

### Python Development Standards
- **Type hints**: Use typing module for function signatures and return types
- **Docstrings**: Include module-level docstrings explaining purpose and usage
- **Exception handling**: Catch specific exceptions and provide meaningful error messages
- **Environment variables**: Use os.getenv() with sensible defaults
- **CLI interfaces**: Provide command-line usage examples in `if __name__ == "__main__"`

## Internal API Usage Patterns

### Lambda Function Structure
```python
# Standard Lambda handler pattern
def lambda_handler(event, context):
    event["_start_time"] = time.time()
    
    # Authorization check
    allowed, approval, deny_reason = authorize_action(event)
    if not allowed:
        return err(403, deny_reason, event)
    
    # Parameter validation
    params, missing = require(event, "required_param1", "required_param2")
    if missing:
        return err(400, f"Missing: {missing}", event)
    
    # Business logic
    result = process_action(params)
    
    # Success response
    return ok(result, event)
```

### S3 Data Access Pattern
```python
# Cached S3 access with fallback
def load_from_s3(bucket, key, cache_key, ttl=300):
    now = time.time()
    if cache_key in _cache:
        data, ts = _cache[cache_key]
        if now - ts < ttl:
            return data
    
    try:
        response = S3.get_object(Bucket=bucket, Key=key)
        data = json.loads(response['Body'].read().decode('utf-8'))
        _cache[cache_key] = (data, now)
        return data
    except Exception as e:
        LOG.error(f"S3 access failed: {e}")
        return None
```

### API Route Pattern (Next.js)
```typescript
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { actionId, params, user } = body;
    
    // Validation
    if (!actionId) {
      return NextResponse.json({ error: "actionId required" }, { status: 400 });
    }
    
    // Business logic
    const result = await processAction(actionId, params, user);
    
    return NextResponse.json(result);
  } catch (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
```

## Frequently Used Code Idioms

### Environment Configuration
```python
# Standard environment variable pattern
BUCKET = os.getenv("EXPORT_BUCKET", "vaultmesh-knowledge-base")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
OPA_URL = os.getenv("OPA_URL")  # Optional, no default
```

### JSON Utilities
```python
# Compact JSON serialization
def _json(o): 
    return json.dumps(o, separators=(",", ":"), ensure_ascii=False)

# Safe JSON parsing
try:
    data = json.loads(response_body)
except json.JSONDecodeError:
    data = response_body  # Keep as string
```

### React State Management
```typescript
// Loading and error state pattern
const [loading, setLoading] = useState(true);
const [error, setError] = useState<string | null>(null);
const [data, setData] = useState<DataType[]>([]);

// Async operation with state updates
async function fetchData() {
  setLoading(true);
  setError(null);
  try {
    const result = await apiCall();
    setData(result);
  } catch (err) {
    setError(err.message);
  } finally {
    setLoading(false);
  }
}
```

## Popular Annotations and Metadata

### TypeScript Interface Patterns
```typescript
// Standard user interface
interface User {
  id?: string;
  groups?: string[];
}

// Action metadata interface
interface ActionEntry {
  id: string;
  name: string;
  description?: string;
  safetyTier?: "GREEN" | "YELLOW" | "RED";
  lambda: string;
  enabled?: boolean;
}
```

### Python Type Annotations
```python
from typing import Dict, Optional, List

def resolve_persona(user_groups: List[str]) -> str:
def load_persona_s3(persona_id: str) -> Optional[Dict]:
def invoke_action(action_id: str, user: Dict, params: Dict, context: Optional[Dict] = None) -> Dict:
```

### Documentation Patterns
```python
"""
Module-level docstring explaining:
1. Purpose and scope
2. Key functions provided  
3. Usage examples
4. Dependencies and requirements
"""

def function_name(param: type) -> return_type:
    """
    Brief description of function purpose.
    
    Args:
        param: Description of parameter
        
    Returns:
        Description of return value
        
    Raises:
        ExceptionType: When this exception occurs
    """
```

## Build and Deployment Standards

### Makefile Patterns
- **Environment loading**: `set -a && . ./.env && set +a` pattern for loading environment
- **Dependency chaining**: Use `&&` to chain dependent operations
- **Output capture**: Use `tee` to capture and display command output
- **Error handling**: Use `set -eo pipefail` for strict error handling
- **Variable defaults**: Use `REGION ?= eu-west-1` for overrideable defaults

### AWS CLI Integration
- **Region consistency**: Default to eu-west-1 across all operations
- **Output formatting**: Use `--output text` for single values, `--output table` for summaries
- **Query filtering**: Use `--query` to extract specific fields from responses
- **Error handling**: Check for required environment variables before AWS operations