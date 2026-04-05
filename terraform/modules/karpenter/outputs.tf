output "controller_role_arn" {
  description = "IRSA role ARN used by the Karpenter controller."
  value       = aws_iam_role.controller.arn
}

output "interruption_queue_arn" {
  description = "ARN of the interruption SQS queue consumed by Karpenter."
  value       = aws_sqs_queue.interruption.arn
}

output "interruption_queue_name" {
  description = "Name of the interruption SQS queue consumed by Karpenter."
  value       = aws_sqs_queue.interruption.name
}
