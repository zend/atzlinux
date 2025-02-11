# 给子域名增加SSL自动续期

## 背景

现在免费 SSL 的有效期全面下调至 90 天，自动续期成为必须。atzlinux.com 的多个子域名，用于各下载镜像使用，这就涉及到这些子域名的SSL证书的自动续期问题。


## 工具选择

个人推荐 acme.sh ，https://github.com/acmesh-official/acme.sh

国内运营商给家庭宽带的 80 端口全部屏蔽了，HTTP验证的路走不通，只能采用 DNS 验证的方式。而 acme.sh 集成了主流的 DNS 验证插件，可以非常简单的完成DNS验证和证书的续期。

## 权限控制

各下载镜像在 DNS 验证时，需要用到DNS提供商侧的密钥，这个密钥一般可以管理整个域名下的全部 DNS 记录，风险极高。
好在腾讯云提供了「[域名共享](https://cloud.tencent.com/document/product/302/104806)」的细粒度权限管控能力，能把一个子域名共享给另外一个腾讯云主账号，授权其管理该子域名及下级孙域名。

## 操作步骤

### 一、域名共享（主域名账号）

在腾讯云解析管理下，增加域名共享

![subdomain-grant](images/subdomain-grant.jpg)

### 二、子账号策略创建（子域名账号）

考虑到子域名的账号下还有其他的资产，可以创建一个子账号，仅授予对应域名的权限。

首先，创建一个自定义策略：
![subdomain-policy](images/subdoamin-policy.png)

也可以直接使用 JSON 文件创建，自己修改其中的 uin 。
```JSON
{
    "statement": [
        {
            "action": [
                "dnspod:*"
            ],
            "effect": "allow",
            "resource": [
                "qcs::dnspod::uin/8******2:domain/mike.atzlinux.com"
            ]
        }
    ],
    "version": "2.0"
}
```


### 三、子账号账号创建（子域名账号）

然后创建子账号，绑定刚建好的自定义策略

![subdomain-accoumt](images/subdomain-account.png)


### 四、获取 API 密钥（子域名账号）

在子账号的详情页中，点击 `API 密钥` Tab，新建密钥。复制保存好。

![subdomain-apikey](images/subdomain-apikey.png)

### 五、安装 acme.sh 并生成证书

```bash
# 安装
curl https://get.acme.sh | sh -s email=my@example.com

# 保存 API 密钥
cat <<EOF >> ~/.acme.sh/acme.sh.env
export Tencent_SecretId="XXXXXXXX"
export Tencent_SecretKey="XXXXXXXXX"
EOF

# 申请证书
acme.sh --issue --dns dns_tencent -d mike.atzlinux.com -d *.mike.atzlinux.com --debug

# 部署证书到 Nginx
acme.sh --install-cert -d mike.atzlinux.com \
  --key-file       /path/to/keyfile/in/nginx/key.pem  \
  --fullchain-file /path/to/fullchain/nginx/cert.pem \
  --reloadcmd     "service nginx reload"
```

成功后，acme.sh 会自动增加 crontab，定期续期证书，证书更新成功后，会自动重启 Nginx 使之生效。


### 六、验证证书有效性

使用 curl 命令确保证书已经更新：

```Bash
$ curl -v -I https://mike.atzlinux.com:58888/ 2>&1 | grep -A6 'Server certificate'
* Server certificate:
*  subject: CN=mike.atzlinux.com
*  start date: Feb 11 01:57:39 2025 GMT
*  expire date: May 12 01:57:38 2025 GMT
*  subjectAltName: host "mike.atzlinux.com" matched cert's "mike.atzlinux.com"
*  issuer: C=US; O=Let's Encrypt; CN=E5
*  SSL certificate verify ok.
```

或者使用浏览器查看。
