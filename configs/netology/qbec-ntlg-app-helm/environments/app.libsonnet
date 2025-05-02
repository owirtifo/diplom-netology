local base = import './base.libsonnet';

base {
  components +: {
    ntlgApp +: {
      replicas: 2,
    },
  }
}
