# EKS Cluster Access Configuration

# Note: SSO Role access is automatically granted by the EKS module
# because we set enable_cluster_creator_admin_permissions = true in main.tf
# The cluster creator (your SSO role) gets automatic admin access!

# No manual access entry needed - it's handled automatically by EKS module ✅

# Note: IAM user 'anudeep' access entry already exists
# Commenting out to avoid "ResourceInUseException"
# You can manually add via AWS Console if needed

/*
resource "aws_eks_access_entry" "iam_user" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = "arn:aws:iam::844333597536:user/anudeep"
  type              = "STANDARD"
  
  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "iam_user" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.iam_user.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.iam_user]
}
*/

