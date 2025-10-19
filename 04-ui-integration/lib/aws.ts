/**
 * VaultMesh Q Business - AWS SDK Helpers (Server-side only)
 *
 * Provides S3 and Lambda client utilities for:
 * - Loading catalog and personas from S3
 * - Invoking RUBEDO action Lambdas
 *
 * IMPORTANT: Never expose these clients to the browser.
 * All AWS calls must remain in server-side API routes.
 */

import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { LambdaClient, InvokeCommand } from "@aws-sdk/client-lambda";
import { Readable } from "node:stream";

const region = process.env.AWS_REGION || "eu-west-1";

export const s3 = new S3Client({ region });
export const lambda = new LambdaClient({ region });

/**
 * Fetch and parse JSON from S3
 */
export async function s3Json<T = any>(bucket: string, key: string): Promise<T> {
  try {
    const res = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
    const body = await streamToString(res.Body as Readable);
    return JSON.parse(body);
  } catch (error: any) {
    throw new Error(`Failed to load s3://${bucket}/${key}: ${error.message}`);
  }
}

/**
 * Convert Readable stream to string
 */
function streamToString(stream: Readable): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    const chunks: Buffer[] = [];
    stream.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
    stream.on("error", reject);
    stream.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
  });
}

/**
 * Invoke Lambda function with payload
 * Returns both HTTP status code and parsed JSON response
 */
export async function invokeLambda(
  functionName: string,
  payload: unknown
): Promise<{ statusCode: number; json: any }> {
  try {
    const res = await lambda.send(
      new InvokeCommand({
        FunctionName: functionName,
        Payload: Buffer.from(JSON.stringify(payload)),
      })
    );

    const body = res.Payload
      ? Buffer.from(res.Payload).toString("utf-8")
      : "{}";

    return {
      statusCode: res.StatusCode ?? 200,
      json: JSON.parse(body),
    };
  } catch (error: any) {
    throw new Error(`Lambda invocation failed (${functionName}): ${error.message}`);
  }
}

/**
 * Check if S3 object exists
 */
export async function s3Exists(bucket: string, key: string): Promise<boolean> {
  try {
    await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
    return true;
  } catch {
    return false;
  }
}
