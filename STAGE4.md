### Подготовка cистемы мониторинга и деплой приложения

Уже должны быть готовы конфигурации для автоматического создания облачной инфраструктуры и поднятия Kubernetes кластера.  
Теперь необходимо подготовить конфигурационные файлы для настройки нашего Kubernetes кластера.

Цель:
1. Задеплоить в кластер [prometheus](https://prometheus.io/), [grafana](https://grafana.com/), [alertmanager](https://github.com/prometheus/alertmanager), [экспортер](https://github.com/prometheus/node_exporter) основных метрик Kubernetes.
2. Задеплоить тестовое приложение, например, [nginx](https://www.nginx.com/) сервер отдающий статическую страницу.

Способ выполнения:
1. Воспользовать пакетом [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus), который уже включает в себя [Kubernetes оператор](https://operatorhub.io/) для [grafana](https://grafana.com/), [prometheus](https://prometheus.io/), [alertmanager](https://github.com/prometheus/alertmanager) и [node_exporter](https://github.com/prometheus/node_exporter). При желании можете собрать все эти приложения отдельно.
2. Для организации конфигурации использовать [qbec](https://qbec.io/), основанный на [jsonnet](https://jsonnet.org/). Обратите внимание на имеющиеся функции для интеграции helm конфигов и [helm charts](https://helm.sh/)
3. Если на первом этапе вы не воспользовались [Terraform Cloud](https://app.terraform.io/), то задеплойте и настройте в кластере [atlantis](https://www.runatlantis.io/) для отслеживания изменений инфраструктуры. Альтернативный вариант 3 задания: вместо Terraform Cloud или atlantis настройте на автоматический запуск и применение конфигурации terraform из вашего git-репозитория в выбранной вами CI-CD системе при любом комите в main ветку. Предоставьте скриншоты работы пайплайна из CI/CD системы.

Ожидаемый результат:
1. Git репозиторий с конфигурационными файлами для настройки Kubernetes.
2. Http доступ к web интерфейсу grafana.
3. Дашборды в grafana отображающие состояние Kubernetes кластера.
4. Http доступ к тестовому приложению.

### Выполнение этапа

Для тестирования будем использовать самоподписанный Wildcard сертификат:

`openssl req -subj "/CN=*.gfg24.com" -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout private.key -out cert.crt`

#### Развертывание kube-prometheus

Для развертывания в кластер Kubernetes системы мониторинга воспользуемся Helm chart [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack), который включает в себя Kubernetes оператор для Grafana, Prometheus, Alertmanager и Node_exporter.

Выполняем установку чарта `kube-prometheus-stack`:

Создаем Secret для использования SSL сертификатов:  
```
kubectl create ns monitoring
kubectl create secret tls grafana-secret-tls -n monitoring --key=/etc/ssl/private.key --cert=/etc/ssl/cert.crt
```

Установка kube-prometheus-stack:
```
cat <<EOF | helm upgrade --install prometheus prometheus-community/kube-prometheus-stack -n monitoring -f -

grafana:
  adminPassword: prom-oper
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/rewrite-target: /
      kubernetes.io/ingress.class: nginx
    hosts: 
    - grafana.gfg24.com
    path: /
    tls:
    - secretName: grafana-secret-tls
      hosts:
      - grafana.gfg24.com
EOF
```

<img align="top" src="img/monitoring.jpg">		<!--![monitoring](img/monitoring.jpg)-->

Для доступа к приложению и web интерфейсу Grafana требуется развернуть Контроллер Nginx Ingress:

```
cat <<EOF | helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set controller.metrics.serviceMonitor.additionalLabels.release="prometheus" -f -
  
controller:
  replicaCount: 2
  service:
    type: NodePort 
    nodePorts:
      http: 32080
      https: 32443
EOF
```
и Облачный балансировщик Yandex Network Load Balancer (NLB) файлом `nlb.tf`:

`terraform apply`

Интерфейс Grafana:

<img align="top" src="img/grafana.jpg">		<!--![grafana](img/grafana.jpg)-->

#### Развертывание Atlantis

Создаем `Git Host Personal access tokens` с областью действия `repo`, который Atlantis будет использовать для выполнения вызовов API:

<img align="top" src="img/atlantis_token.jpg">		<!--![atlantis_token](img/atlantis_token.jpg)-->

Создаем `Branch protection rule` для включения обязательного создания Pull Request:

<img align="top" src="img/atlantis_branch_rule.jpg">		<!--![atlantis_branch_rule](img/atlantis_branch_rule.jpg)-->

**Примечание.** В данном случае убираем галочку `Require approvals`, так как будет использоваться только один `Collaborator`:

<img align="top" src="img/repo_collaborator.jpg">		<!--![repo_collaborator](img/repo_collaborator.jpg)-->

В репозитории с кодом приложения [app-netology-repo](https://github.com/owirtifo/app-netology-repo) создаем `Webhook`, чтобы иметь возможность запускать Atlantis при создании Pull request events. Указываем `Webhook Secret` для  проверки подлинности вебхуков, которые Atlantis будет получать от хоста Git. В поле `Payload URL` обязательно добавьте `/events` в конец своего URL. В `Which events would you like to trigger this webhook?` выберите `Let me select individual events.` и отметьте флажки:
* Pull request reviews
* Pushes
* Issue comments
* Pull requests

<img align="top" src="img/atlantis_webhook.jpg">		<!--![atlantis_webhook](img/atlantis_webhook.jpg)-->

<img align="top" src="img/atlantis_webhook_1.jpg">		<!--![atlantis_webhook_1](img/atlantis_webhook_1.jpg)-->

Выполняем развертывание Atlantis:

Создаем Secret для использования SSL сертификатов:  
```
kubectl create ns atlantis
kubectl create secret tls atlantis-secret-tls -n atlantis --key=/etc/ssl/private.key --cert=/etc/ssl/cert.crt
```

Содаем файл с GitHub токеном:  
`echo -n "<gh_token>" > gh-token`

Содаем файл с Webhook Secret:  
`echo -n "<webhook_secret>" > gh-webhook-secret`

Содаем файл c Яндекс токеном:  
`echo -n "<yc_token>" > yc-token`

Содаем файлы для доступа к Backend:  
```
echo -n "<access_key>" > bk-access-key
echo -n "<secret_key>" > bk-secret-key
```

Создаем Secret с созданными учетными данными:  
```
kubectl create secret generic atlantis-vcs --from-file=gh-token --from-file=gh-webhook-secret --from-file=yc-token --from-file=bk-access-key --from-file=bk-secret-key -n atlantis
```

Создаем Secret с публичным ключем для подключения к виртуальным машинам:  
`kubectl create secret generic atlantis-ssh-key --from-file=$HOME/.ssh/id_rsa.pub -n atlantis`

Деплоим Atlantis:  
`kubectl apply -f kube-deploy-atlantis.yaml -n atlantis`

<img align="top" src="img/atlantis.jpg">		<!--![atlantis](img/atlantis.jpg)-->

Создадим тестовый Pull Request с созданием подсети в зоне `ru-central1-d`:

<img align="top" src="img/create_pr.jpg">		<!--![create_pr](img/create_pr.jpg)-->

Вывод планов:

<img align="top" src="img/atlantis_plan.jpg">		<!--![atlantis_plan](img/atlantis_plan.jpg)-->

<img align="top" src="img/atlantis_plan_1.jpg">		<!--![atlantis_plan_1](img/atlantis_plan_1.jpg)-->

<img align="top" src="img/atlantis_1.jpg">		<!--![atlantis_1](img/atlantis_1.jpg)-->

Применяем только для stage:

`atlantis apply -w stage`

<img align="top" src="img/atlantis_apply.jpg">		<!--![atlantis_apply](img/atlantis_apply.jpg)-->

И мерджим PR:

<img align="top" src="img/merge_pr.jpg">		<!--![merge_pr](img/merge_pr.jpg)-->

<img align="top" src="img/atlantis_2.jpg">		<!--![atlantis_2](img/atlantis_2.jpg)-->

Проверяем создание подсети в зоне `ru-central1-d`:

<img align="top" src="img/atlantis_add_subnet.jpg">		<!--![atlantis_add_subnet](img/atlantis_add_subnet.jpg)-->

#### Развертывание приложения с помощью Qbec

Создаем Secret для использования SSL сертификатов:  
```
kubectl create ns app
kubectl create secret tls app-secret-tls -n app --key=/etc/ssl/private.key --cert=/etc/ssl/cert.crt
```

Необходимо изменить IP адрес Master ноды в файле qbec.yaml:

```
spec:
  environments:
    app:
      defaultNamespace: app
      server: https://<ip_address>:6443
```

Запускаем Qbec:  
`LAST_TAG=v1.0.0 qbec apply app --vm:ext-str LAST_TAG`

<img align="top" src="img/qbec_apply.jpg">		<!--![qbec_apply](img/qbec_apply.jpg)-->

<img align="top" src="img/kube_app_deploy.jpg">		<!--![kube_app_deploy](img/kube_app_deploy.jpg)-->

Проверка:

<img align="top" src="img/app-ntlg.jpg">		<!--![app-ntlg](img/app-ntlg.jpg)-->