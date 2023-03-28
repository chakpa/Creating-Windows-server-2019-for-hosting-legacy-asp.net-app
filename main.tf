provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

variable "subnet_prefix" {
  description = "cidr block for the subnet"

}

# # 1. Create vpc

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}



# # 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
   vpc_id = aws_vpc.prod-vpc.id


 }
# # 3. Create Custom Route Table

 resource "aws_route_table" "prod-route-table" {
 vpc_id = aws_vpc.prod-vpc.id

 route {
    cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id
  }

   route {
   ipv6_cidr_block = "::/0"
  gateway_id      = aws_internet_gateway.gw.id
 }

 tags = {
    Name = "Prod"
   }
 }

# # 4. Create a Subnet 

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
 cidr_block        = "10.0.1.0/24"
availability_zone = "us-east-1a"

 tags = {
   Name = "prod-subnet"
  }
 }

# # 5. Associate subnet with Route Table
resource "aws_route_table_association" "a" {
 subnet_id      = aws_subnet.subnet-1.id
   route_table_id = aws_route_table.prod-route-table.id
 }
# # 6. Create Security Group to allow port 80,443, 3389
 resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
   vpc_id      = aws_vpc.prod-vpc.id

   ingress {
     description = "HTTPS"
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ingress {
    description = "HTTP"
     from_port   = 80
     to_port     = 80
    protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
     to_port     = 0
     protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
   }

     tags = {
     Name = "allow_web"
   }
 
 }

 # # 7. Create a network interface with an ip in the subnet that was created in step 4

 resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
   security_groups = [aws_security_group.allow_web.id]

}
# # 8. Assign an elastic IP to the network interface created in step 7

 resource "aws_eip" "one" {
   vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
 }

 output "server_public_ip" {
  value = aws_eip.one.public_ip
 }

# # 9. Create windows server and enable IIs

 resource "aws_instance" "windows_server2019" {
  ami           = "ami-03a21b62905737826"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.windows_server2019.id
  vpc_security_group_ids = [aws_security_group.windows_server2019.id]

  tags = {
    Name = "windows_server2019"
  }

  user_data = <<-EOF
              <powershell>

              Install-WindowsFeature -name Web-Server -IncludeManagementTools
              New-Item -Path C:\inetpub\wwwroot\index.html -ItemType File -Value "asp.net .net Framework 4.8" -For
              Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
              Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
              Invoke-WebRequest -Uri https://download.microsoft.com/download/5/E/9/5E9B18CC-8FD5-467E-B5BF-BADE39C51F73/SQLServer2017-SSEI-Expr.exe -OutFile C:\SQLServer2017.exe
              Start-Process -FilePath C:\SQLServer2017.exe -ArgumentList "/QS", "/IACCEPTSQLSERVERLICENSETERMS", "/ACTION=Install", "/FEATURES=SQLEngine", "/INSTANCENAME=MSSQLSERVER", "/SECURITYMODE=SQL", "/SAPWD=Password@123" -Wait
              
              </powershell>
              EOF
}

 output "server_private_ip" {
  value = aws_instance.web-server-instance.private_ip

 }

 output "server_id" {
   value = aws_instance.web-server-instance.id
 }
