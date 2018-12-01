package wgm

import grails.gorm.services.Service

@Service(Imagem)
interface ImagemService {

    Imagem get(Serializable id)

    List<Imagem> list(Map args)

    Long count()

    void delete(Serializable id)

    Imagem save(Imagem imagem)

}