## This file was auto-generated by CloudCoreo CLI
## This file was automatically generated using the CloudCoreo CLI
##
## This config.rb file exists to create and maintain services not related to compute.
## for example, a VPC might be maintained using:
##
## coreo_aws_vpc_vpc "my-vpc" do
##   action :sustain
##   cidr "12.0.0.0/16"
##   internet_gateway true
## end
##

coreo_aws_s3_policy "${BACKUP_BUCKET}-policy" do
  action :sustain
  policy_document <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${BACKUP_BUCKET}/*",
        "arn:aws:s3:::${BACKUP_BUCKET}"
      ]
    }
  ]
}
EOF
end

coreo_aws_s3_bucket "${BACKUP_BUCKET}" do
   action :sustain
   bucket_policies ["${BACKUP_BUCKET}-policy"]
   region "${BACKUP_BUCKET_REGION}"
end

coreo_aws_s3_policy "${VPN_KEY_BUCKET}-policy" do
  action :sustain
  policy_document <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${VPN_KEY_BUCKET}/*",
        "arn:aws:s3:::${VPN_KEY_BUCKET}"
      ]
    }
  ]
}
EOF
end

coreo_aws_s3_bucket "${VPN_KEY_BUCKET}" do
   action :sustain
   bucket_policies ["${VPN_KEY_BUCKET}-policy"]
   region "${VPN_KEY_BUCKET_REGION}"
end

coreo_aws_ec2_securityGroups "${VPN_NAME}-elb-sg" do
  action :sustain
  description "Open vpn to the world"
  vpc "${VPC_NAME}"
  allows [ 
          { 
            :direction => :ingress,
            :protocol => :tcp,
            :ports => [1199],
            :cidrs => ${VPN_ACCESS_CIDRS},
          },{ 
            :direction => :egress,
            :protocol => :tcp,
            :ports => ["0..65535"],
            :cidrs => ${VPN_ACCESS_CIDRS},
          }
    ]
end

coreo_aws_ec2_elb "${VPN_NAME}-elb" do
  action :sustain
  type "public"
  vpc "${VPC_NAME}"
  subnet "${PUBLIC_SUBNET_NAME}"
  security_groups ["${VPN_NAME}-elb-sg"]
  listeners [
             {
               :elb_protocol => 'tcp', 
               :elb_port => 1199, 
               :to_protocol => 'tcp', 
               :to_port => 1199
             }
            ]
  health_check_protocol 'tcp'
  health_check_port "1199"
  health_check_timeout 5
  health_check_interval 120
  health_check_unhealthy_threshold 5
  health_check_healthy_threshold 2
end

coreo_aws_route53_record "${VPN_NAME}" do
  action :sustain
  type "CNAME"
  zone "${DNS_ZONE}"
  values ["STACK::coreo_aws_ec2_elb.${VPN_NAME}-elb.dns_name"]
end

coreo_aws_ec2_securityGroups "${VPN_NAME}-sg" do
  action :sustain
  description "Open vpn connections to the world"
  vpc "${VPC_NAME}"
  allows [ 
          { 
            :direction => :ingress,
            :protocol => :tcp,
            :ports => [1199],
            :groups => ["${VPN_NAME}-elb-sg"],
          },{ 
            :direction => :ingress,
            :protocol => :tcp,
            :ports => [22],
            :cidrs => ${VPN_SSH_ACCESS_CIDRS},
          },{ 
            :direction => :egress,
            :protocol => :tcp,
            :ports => ["0..65535"],
            :cidrs => ["0.0.0.0/0"],
          }
    ]
end

coreo_aws_iam_policy "${VPN_NAME}-route53" do
  action :sustain
  policy_name "${VPN_NAME}Route53Management"
  policy_document <<-EOH
{
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
          "*"
      ],
      "Action": [ 
          "route53:*"
      ]
    }
  ]
}
EOH
end

coreo_aws_iam_policy "${VPN_NAME}-backup" do
  action :sustain
  policy_name "Allow${VPN_NAME}S3Backup"
  policy_document <<-EOH
{
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${BACKUP_BUCKET}/${REGION}/vpn/${ENV}/${VPN_NAME}",
          "arn:aws:s3:::${BACKUP_BUCKET}/${REGION}/vpn/${ENV}/${VPN_NAME}/*"
      ],
      "Action": [ 
          "s3:*"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::*",
      "Action": [
          "s3:ListAllMyBuckets"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${BACKUP_BUCKET}",
          "arn:aws:s3:::${BACKUP_BUCKET}/*"
      ],
      "Action": [
          "s3:GetBucket*", 
          "s3:List*" 
      ]
    }
  ]
}
EOH
end

coreo_aws_iam_policy "${VPN_NAME}-vpn-key-files" do
  action :sustain
  policy_name "Allow${VPN_NAME}VpnKeyAccess"
  policy_document <<-EOH
{
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${VPN_KEY_BUCKET}/vpn/${VPN_NAME}",
          "arn:aws:s3:::${VPN_KEY_BUCKET}/vpn/${VPN_NAME}/*"
      ],
      "Action": [ 
          "s3:*"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::*",
      "Action": [
          "s3:ListAllMyBuckets"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${VPN_KEY_BUCKET}",
          "arn:aws:s3:::${VPN_KEY_BUCKET}/*"
      ],
      "Action": [
          "s3:GetBucket*", 
          "s3:List*" 
      ]
    }
  ]
}
EOH
end

coreo_aws_iam_instance_profile "${VPN_NAME}" do
  action :sustain
  policies ["${VPN_NAME}-route53", "${VPN_NAME}-backup", "${VPN_NAME}-vpn-key-files"]
end

coreo_aws_ec2_instance "${VPN_NAME}" do
  action :define
  upgrade_trigger "1"
  image_id "${VPN_AMI_ID}"
  size "${VPN_INSTANCE_TYPE}"
  security_groups ["${VPN_NAME}-sg"]
  ssh_key "${VPN_SSH_KEY_NAME}"
  role "${VPN_NAME}"
end

coreo_aws_ec2_autoscaling "${VPN_NAME}" do
  action :sustain 
  minimum 1
  maximum 1
  server_definition "${VPN_NAME}"
  subnet "${PRIVATE_SUBNET_NAME}"
  elbs ["${VPN_NAME}-elb"]
end
