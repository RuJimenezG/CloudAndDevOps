terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-1"
}

# RDS Postgres
resource "aws_db_instance" "rds_postgresql" {
  allocated_storage    = 25
  engine               = "postgres"
  engine_version       = "14.7"
  instance_class       = "db.t3.micro"
  db_name              = var.database_name
  identifier           = var.database_identifier
  username             = var.user_name
  password             = var.db_password
  parameter_group_name = "default.postgres14"
  publicly_accessible  = true
  skip_final_snapshot  = true
}

# Crear función Lambda
resource "aws_lambda_function" "APILibros" {
  filename      = "lambda.zip"
  function_name = "APILibros"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  environment {
    variables = {
      "host"     = "${split(":", aws_db_instance.rds_postgresql.endpoint)[0]}"
      "username" = var.user_name
      "password" = var.db_password
      "database" = var.database_name
    }
  }
  vpc_config {
    security_group_ids = [
      var.sec_group,
      ]
    subnet_ids         = [
      var.subnet_id1,
      var.subnet_id2,
      ]
  }
}

# Crear IAM Role para la función Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Agregar política de permisos para enviar registros a CloudWatch
resource "aws_iam_role_policy" "lambda_cloudwatch_policy" {
  name = "lambda_cloudwatch_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
  role = aws_iam_role.lambda_role.id
}

# Crear inline policy para permitir acceso a RDS
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds-db:connect"
        ]
        Effect   = "Allow"
        Resource = aws_db_instance.rds_postgresql.arn
      },
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  role = aws_iam_role.lambda_role.id
}

# Añadir permisos de ejecución de la función Lambda a la policy
resource "aws_lambda_permission" "APILibros" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.APILibros.function_name
  principal     = "apigateway.amazonaws.com"

  # ARN de la API Gateway
  source_arn = "${aws_api_gateway_rest_api.APILibros.execution_arn}/*/*/libros"
}

# Creamos una instancia de API Gateway
resource "aws_api_gateway_rest_api" "APILibros" {
  name = "APILibros"
}

resource "aws_api_gateway_method" "libros_OPTIONS" {
  rest_api_id   = aws_api_gateway_rest_api.APILibros.id
  resource_id   = aws_api_gateway_resource.libros.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "libros_OPTIONS" {
  rest_api_id             = aws_api_gateway_rest_api.APILibros.id
  resource_id             = aws_api_gateway_resource.libros.id
  http_method             = aws_api_gateway_method.libros_OPTIONS.http_method
  integration_http_method = "OPTIONS"
  type                    = "MOCK"
}

# Creamos un recurso llamado "libros" y lo asociamos con la instancia de API Gateway
resource "aws_api_gateway_resource" "libros" {
  rest_api_id = aws_api_gateway_rest_api.APILibros.id
  parent_id   = aws_api_gateway_rest_api.APILibros.root_resource_id
  path_part   = "libros"
}

# Añadimos los métodos GET y POST para el recurso "libros"
resource "aws_api_gateway_method" "libros_GET" {
  rest_api_id   = aws_api_gateway_rest_api.APILibros.id
  resource_id   = aws_api_gateway_resource.libros.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "libros_POST" {
  rest_api_id   = aws_api_gateway_rest_api.APILibros.id
  resource_id   = aws_api_gateway_resource.libros.id
  http_method   = "POST"
  authorization = "NONE"
}

# Creamos una integración de tipo Lambda para cada método
resource "aws_api_gateway_integration" "libros_GET_integration" {
  rest_api_id             = aws_api_gateway_rest_api.APILibros.id
  resource_id             = aws_api_gateway_resource.libros.id
  http_method             = aws_api_gateway_method.libros_GET.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.APILibros.invoke_arn
}

resource "aws_api_gateway_integration" "libros_POST_integration" {
  rest_api_id             = aws_api_gateway_rest_api.APILibros.id
  resource_id             = aws_api_gateway_resource.libros.id
  http_method             = aws_api_gateway_method.libros_POST.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.APILibros.invoke_arn
}

# Creamos el deployment
resource "aws_api_gateway_deployment" "APILibros" {
  depends_on      = [aws_api_gateway_integration.libros_GET_integration, aws_api_gateway_integration.libros_POST_integration]
  rest_api_id     = aws_api_gateway_rest_api.APILibros.id
  stage_name      = "dev"
  description     = "Deployment para API de libros"
}