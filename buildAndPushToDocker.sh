set +e

s2i build . ceylon/s2i-ceylon:1.3.3-jre8 f8tenant-che-migration-deploy

if [ "$TAG" != "" ];
then
  tag_push ${REGISTRY}/${NAMESPACE}/fabric8-tenant-che-migration:$TAG
fi
tag_push ${REGISTRY}/${NAMESPACE}/fabric8-tenant-che-migration:latest
