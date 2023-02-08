locals {
  http_port = 80
  any_port = 0
  any_protocol = "-1"
  all_ips = "0.0.0.0/0"
}
resource "aws_launch_configuration" "sergi-server" {
 image_id = "ami-00874d747dde814fa"
 instance_type = "t2.micro"
 security_groups = [aws_security_group.sg-lb-sergi.id]

lifecycle {
    create_before_destroy = true
}





user_data= <<-EOF
    #!/bin/bash
    echo "Hala Celta" >> index.html
    echo "${data.terraform_remote_state.db.outputs.address}" >> index.html 

    echo "${data.terraform_remote_state.db.outputs.port}" >> index.html 
    nohup busybox httpd -f -p ${var.server_port} & 
    EOF
#extrayendo del tfstate los datos de la bbdd, está en los outputs(pòrque lo pusimos alli)
# el address y el port
}
   


resource "aws_security_group_rule" "allow_all_outbound" {
  type = "egress"
  from_port = local.any_port
  to_port = local.any_port
  protocol = local.any_protocol
  cidr_blocks = [local.all_ips]
  security_group_id = aws_security_group.sg-lb-sergi.id
}

resource "aws_security_group_rule" "allow_all_inbound" {
  type = "ingress"
  from_port = local.any_port
  to_port = local.any_port
  protocol = local.any_protocol
  cidr_blocks = [local.all_ips]
  security_group_id = aws_security_group.sg-lb-sergi.id
}

resource "aws_security_group" "sg-lb-sergi" {
  
}

resource "aws_autoscaling_group" "sergi-server" {
 launch_configuration = aws_launch_configuration.sergi-server.name
 vpc_zone_identifier = data.aws_subnets.default.ids # ,aws_subnet.sergi-server2.id]?
 min_size = 2
 max_size = 10

  tag {
    key     = "NAME"
    value = "sergi-server" #terraform-asg-example
    propagate_at_launch = true 
}
}





data "aws_vpc" "default" { #llamarlo sergi-data??
  default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
   }
    }



data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    #1:1 mapeo organizacion directorios
    key = var.db_remote_state_key #Podriamos cambiar el mapeo, pero seguiria en el mismo lugar, ya lo hemos asignado
    region = "us-east-1"
  }
}



resource "aws_security_group" "SGteraform" {
  ingress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_lb" "sergi-server" {
  name                =   "alb-sergi"
  internal            =    false
  load_balancer_type  =   "application"
  security_groups     =    [aws_security_group.sg-lb-sergi.id]
  subnets             =    data.aws_subnets.default.ids
  
}

resource "aws_lb_target_group" "sergi-server" {
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id
  
  lifecycle {
    create_before_destroy = true
  }
  
}

resource "aws_lb_listener" "sergi-server" {
  load_balancer_arn = aws_lb.sergi-server.arn
  port = local.http_port
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.sergi-server.arn
  }
}